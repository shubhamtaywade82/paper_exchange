require 'rails_helper'

RSpec.describe MarketData::CandleBuilder, type: :service do
  it 'builds candles from ticks' do
    builder = described_class.new
    candle = nil
    ticks = Array.new(3) { |i| { timestamp: Time.current, price: 100 + i, volume: 10 } }
    expect { candle = builder.build_from(ticks) }.not_to raise_error
    expect(candle[:open]).to eq(100)
  end

  it 'correctly aligns 5m candle to the current 5-minute bucket' do
    builder = described_class.new
    test_time = Time.zone.parse('2026-10-04 10:17:30')
    candle = builder.build_from([ { symbol: 'BTCUSDT', timestamp: test_time, price: 100, volume: 1 } ])
    expect(candle[:started_at]).to eq(Time.zone.parse('2026-10-04 10:15:00'))
  end
end
