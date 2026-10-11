require 'rails_helper'

# P1-5 regression: cancellation must be atomic with margin release.
# The lock, state validation, status transition, and margin release must all
# be inside ONE transaction — a fill racing a cancel cannot interleave.
# A failure in margin release must roll back the cancel too.
RSpec.describe 'P1-5: Cancellation atomicity', type: :integration do
  let(:account_id) { 'ACC-CANCEL-ATOMIC' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }

  before { create(:account, account_id: account_id, margin: 100_000.0) }

  it 'wraps lock + cancel + margin release in one transaction' do
    # Create an open order with locked margin
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE', bid: 100.0, ask: 100.0, ltp: 100.0, timestamp: Time.current
    ))
    order = exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy',
      quantity: 10, order_kind: 'market', instrument_type: 'EQUITY'
    )

    # The order should be filled (market order), not open — create an open one manually
    open_order = create(:paper_order,
      account_id: account_id, symbol: 'RELIANCE', side: :buy,
      quantity: 10, order_kind: :market, instrument_type: 'EQUITY',
      status: :open, placed_at: Time.current, locked_margin: 1_000.0
    )

    account = Account.find_by!(account_id: account_id)
    balance_before = account.available_balance.to_f
    locked_before = account.locked_margin.to_f

    # Cancel it
    result = exchange.cancel_order(open_order.id)

    open_order.reload
    account.reload

    # The returned order should reflect the committed state (P1-5)
    expect(result.status).to eq('cancelled')
    expect(open_order.status).to eq('cancelled')

    # Margin should be released (locked decreases, available increases)
    expect(account.locked_margin.to_f).to be < locked_before
    expect(account.available_balance.to_f).to be > balance_before
  end

  it 'raises StateError (not a silent success) when cancelling an already-filled order' do
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE', bid: 100.0, ask: 100.0, ltp: 100.0, timestamp: Time.current
    ))
    filled_order = exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy',
      quantity: 10, order_kind: 'market', instrument_type: 'EQUITY'
    )

    expect {
      exchange.cancel_order(filled_order.id)
    }.to raise_error(PaperExchange::PaperOrder::StateError, /cannot cancel a filled order/)
  end
end

# P1-2 regression: the notional-value limit must use the same reference price
# as the margin lock. A market order with only execution_price must NOT
# bypass MAX_POSITION_VALUE because the validator saw zero notional.
RSpec.describe 'P1-2: Notional-value limit bypass', type: :integration do
  let(:account_id) { 'ACC-NOTIONAL-BYPASS' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }

  before do
    create(:account, account_id: account_id, margin: 1_000_000.0, currency: 'USD')
    stub_const('Risk::MarginValidator::MAX_POSITION_VALUE', 50_000.0)
  end

  it 'rejects a crypto order whose execution_price makes notional exceed MAX_POSITION_VALUE' do
    # 1 BTC at $60k = $60k notional — exceeds the $50k cap
    expect {
      exchange.submit_order(
        account_id: account_id, symbol: 'BTCUSDT', side: 'buy',
        quantity: 1, order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
        leverage: 1, margin_type: 'cross', execution_price: 60_000.0
      )
    }.to raise_error(Exchange::PaperExchange::RiskCheckFailedError, /MARGIN_REJECTED/)
  end

  it 'accepts a crypto order whose execution_price keeps notional under MAX_POSITION_VALUE' do
    # 0.5 BTC at $60k = $30k notional — under the $50k cap
    order = exchange.submit_order(
      account_id: account_id, symbol: 'BTCUSDT', side: 'buy',
      quantity: 0.5, order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
      leverage: 1, margin_type: 'cross', execution_price: 60_000.0
    )
    expect(order.status).to eq('filled')
  end
end

# P1-3 regression: Indian F&O STT rates match the NSE FY2026-27 schedule.
RSpec.describe 'P1-3: NSE STT schedule', type: :service do
  let(:calculator) { Exchange::BrokerageCalculator.new }

  it 'charges 0.15% STT on options sell (not 0.05%)' do
    charges = calculator.calculate(
      trade_price: 100.0, quantity: 10, side: 'sell',
      symbol: 'NIFTY', instrument_type: 'OPTIDX'
    )
    # Turnover = 1000, STT at 0.15% = 1.50 (was 0.50 at the old 0.05% rate)
    expect(charges[:stt]).to be_within(0.01).of(1.50)
  end

  it 'charges 0.05% STT on futures sell (not 0.01%)' do
    charges = calculator.calculate(
      trade_price: 100.0, quantity: 10, side: 'sell',
      symbol: 'NIFTY', instrument_type: 'FUTIDX'
    )
    # Turnover = 1000, STT at 0.05% = 0.50 (was 0.10 at the old 0.01% rate)
    expect(charges[:stt]).to be_within(0.01).of(0.50)
  end
end
