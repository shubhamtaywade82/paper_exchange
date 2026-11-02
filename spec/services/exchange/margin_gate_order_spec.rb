require 'rails_helper'

# Regression spec (live path, margin double-count). submit_order locked the
# order's margin before the risk gate ran, and MarginValidator then compared
# the order with available_balance, which already excluded that lock. Any order
# needing more than half the free balance was rejected with MARGIN_REJECTED
# even when the account could afford it.
RSpec.describe 'Margin gate on order submission', type: :service do
  let(:account_id) { 'ACC-MARGIN-GATE' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }

  before do
    create(:account, account_id: account_id, margin: 10_000.0)
    exchange.market_event(MarketData::MarketEvent.new(symbol: 'RELIANCE', bid: 100.0, ask: 100.0, ltp: 100.0, timestamp: Time.current))
  end

  it 'fills a buy that needs 60% of the free balance (margin double-count regression guard)' do
    order = exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy', quantity: 60,
      order_kind: 'market', instrument_type: 'EQUITY'
    )

    expect(order.status).to eq('filled')
    expect(order.rejection_reason).to be_nil
  end

  # A cash shortfall keeps its documented status (402, InsufficientMarginError).
  it 'still refuses a buy the account cannot afford, with the 402 error' do
    expect {
      exchange.submit_order(
        account_id: account_id, symbol: 'RELIANCE', side: 'buy', quantity: 120,
        order_kind: 'market', instrument_type: 'EQUITY'
      )
    }.to raise_error(Ledger::InsufficientMarginError)
  end

  it 'leaves no margin locked behind a refused order' do
    expect {
      exchange.submit_order(
        account_id: account_id, symbol: 'RELIANCE', side: 'buy', quantity: 120,
        order_kind: 'market', instrument_type: 'EQUITY'
      )
    }.to raise_error(Ledger::InsufficientMarginError)

    account = Account.find_by!(account_id: account_id)
    expect(account.available_balance).to eq(10_000)
    expect(account.locked_margin).to eq(0)
    expect(LedgerEntry.where(account_id: account_id, event_type: 'MARGIN_LOCKED')).to be_empty
  end
end
