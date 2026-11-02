require 'rails_helper'

# Regression spec (live path). MatchingEngine#execute called #positive? on the
# :unfilled symbol returned for a non-marketable limit or stop order. The
# NoMethodError was rescued and the order was marked rejected, so no limit or
# stop order could rest on the book. A resting order must stay open, keep its
# margin locked, and fill later through match_and_fill.
RSpec.describe 'Resting limit and stop orders', type: :service do
  let(:account_id) { 'ACC-RESTING' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }

  before do
    create(:account, account_id: account_id, margin: 100_000.0)
    exchange.market_event(MarketData::MarketEvent.new(symbol: 'RELIANCE', bid: 100.0, ask: 100.5, ltp: 100.25, timestamp: Time.current))
  end

  it 'keeps a non-marketable buy limit open instead of rejecting it' do
    order = exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy', quantity: 10,
      order_kind: 'bounded', price: 99.0, instrument_type: 'EQUITY'
    )

    expect(order.status).to eq('open')
    expect(order.rejection_reason).to be_nil
    expect(Account.find_by!(account_id: account_id).locked_margin).to eq(990)
  end

  it 'keeps a stop order open until its trigger is reached' do
    order = exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'sell', quantity: 10,
      order_kind: 'stop_loss', trigger_price: 95.0, instrument_type: 'EQUITY'
    )

    expect(order.status).to eq('open')
  end

  it 'still fills an order that is marketable at submission' do
    order = exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy', quantity: 10,
      order_kind: 'bounded', price: 101.0, instrument_type: 'EQUITY'
    )

    expect(order.status).to eq('filled')
  end

  it 'fills a resting limit when match_and_fill is called with a crossing price' do
    order = exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy', quantity: 10,
      order_kind: 'bounded', price: 99.0, instrument_type: 'EQUITY'
    )

    filled = exchange.match_and_fill(order.reload, 98.8)

    expect(filled.status).to eq('filled')
    expect(PaperExchange::PaperTrade.find_by(paper_order_id: order.id).price).to eq(98.8)
  end
end
