require 'rails_helper'

RSpec.describe MarketData::MarketEvent, type: :service do
  subject(:event) { described_class.new(symbol: 'NIFTY', bid: 100, ask: 101, ltp: 100.5, timestamp: Time.current) }

  it 'stores event attributes' do
    expect(event.symbol).to eq('NIFTY')
    expect(event.ltp).to eq(100.5)
  end
end
