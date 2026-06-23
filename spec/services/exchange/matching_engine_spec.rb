require 'rails_helper'

RSpec.describe Exchange::MatchingEngine, type: :service do
  let(:slippage) { instance_double('Exchange::SlippageEngine', fill_price: 100.0) }
  let(:latency) { instance_double('Exchange::LatencyEngine', simulate: nil) }
  let(:order_book) { Exchange::OrderBook.new(Mutex.new, {}) }
  let(:engine) { described_class.new(order_book: order_book, slippage: slippage, latency: latency) }

  it 'executes market order' do
    order = create(:paper_order, symbol: 'RELIANCE', side: 'buy', order_kind: 'market', quantity: 10, instrument_type: 'EQUITY')
    order_book.apply_snapshot('RELIANCE', bid: 99.5, ask: 100.5, ltp: 100.0)
    result = engine.execute(order)
    expect(result).to be_an(Array)
  end
end
