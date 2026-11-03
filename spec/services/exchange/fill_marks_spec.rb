require 'rails_helper'

# A fill is an execution, not market data. It must not move the mark price that
# protections and projections read.
RSpec.describe Exchange::PaperExchange, 'fills and mark prices', type: :service do
  let(:account_id) { 'ACC-MARKS' }
  let(:exchange) { described_class.new(account_id: account_id) }

  before do
    create(:account, account_id: account_id, margin: 100_000.0)
    MarketData::MarkPriceStore.clear
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE', bid: 100, ask: 101, ltp: 100.5, timestamp: Time.current
    ))
  end

  it 'leaves the mark unchanged after a market fill' do
    order = exchange.submit_order(account_id: account_id, symbol: 'RELIANCE', side: 'buy', quantity: 10,
      order_kind: 'market', instrument_type: 'EQUITY')

    expect(order.status).to eq('filled')
    expect(MarketData::MarkPriceStore.get('RELIANCE')).to be_nil
  end

  it 'leaves the mark unchanged when the client supplies an execution price' do
    exchange.submit_order(account_id: account_id, symbol: 'RELIANCE', side: 'buy', quantity: 10,
      order_kind: 'market', instrument_type: 'EQUITY', execution_price: 102.0)

    expect(MarketData::MarkPriceStore.get('RELIANCE')).to be_nil
  end
end
