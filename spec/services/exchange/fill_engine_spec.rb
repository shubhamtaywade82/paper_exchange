require 'rails_helper'

RSpec.describe Exchange::FillEngine, type: :service do
  let(:slippage) { instance_double('Exchange::SlippageEngine', fill_price: 100.0) }
  let(:engine) { described_class.new(slippage: slippage) }

  it 'fills market order' do
    order = create(:paper_order, symbol: 'RELIANCE', side: 'buy', order_kind: 'market', quantity: 10, instrument_type: 'EQUITY')
    book = { bid: 99.5, ask: 100.5, ltp: 100.0 }
    fill_qty, fill_price, trade = engine.fill(order, market_snapshot: book, instrument_type: 'EQUITY', quantity: 10)
    expect(fill_qty).to eq(10)
    expect(fill_price).to eq(100.0)
    expect(trade).to be_present
  end
end
