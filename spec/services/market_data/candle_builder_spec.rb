require 'rails_helper'

RSpec.describe MarketData::CandleBuilder, type: :service do
  it 'builds candles from ticks' do
    builder = described_class.new
    candle = nil
    ticks = Array.new(3) { |i| { timestamp: Time.current, price: 100 + i, volume: 10 } }
    expect { candle = builder.build_from(ticks) }.not_to raise_error
    expect(candle[:open]).to eq(100)
  end
end
