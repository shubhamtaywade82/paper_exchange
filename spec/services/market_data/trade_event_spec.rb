require 'rails_helper'

RSpec.describe MarketData::TradeEvent, type: :service do
  it 'builds with trade attributes' do
    event = described_class.new(trade_id: 1, order_id: 1, account_id: 'A', symbol: 'NIFTY', side: 'buy', quantity: 10, price: 100.0, traded_at: Time.current)
    expect(event.trade_id).to eq(1)
  end
end
