require 'rails_helper'

RSpec.describe MarketData::OrderEvent, type: :service do
  it 'builds with order attributes' do
    event = described_class.new(order_id: 1, account_id: 'A', symbol: 'NIFTY', side: 'buy', order_type: 'market', quantity: 10, price: nil, trigger_price: nil, status: 'open', timestamp: Time.current)
    expect(event.order_id).to eq(1)
    expect(event.status).to eq('open')
  end
end
