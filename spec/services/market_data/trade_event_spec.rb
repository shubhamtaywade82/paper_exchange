require 'rails_helper'

RSpec.describe MarketData::TradeEvent, type: :service do
  it 'builds with trade attributes' do
    event = described_class.new(trade_id: 1, order_id: 1, account_id: 'A', symbol: 'NIFTY', side: 'buy', quantity: 10, trade_price: 100.0, trade_type: 'regular', timestamp: Time.current)
    expect(event.trade_id).to eq(1)
  end
end
