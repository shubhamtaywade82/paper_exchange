require 'rails_helper'

RSpec.describe Strategy::IndicatorEngine, type: :service do
  it 'stores prices and computes sma_20 after 20 ticks' do
    engine = described_class.new
    event = MarketData::MarketEvent.new(symbol: 'RELIANCE', ltp: 100.0, bid: 99.5, ask: 100.5, timestamp: Time.current)
    20.times { |i| engine.ingest(MarketData::MarketEvent.new(symbol: 'RELIANCE', ltp: 100.0 + i, bid: 100.0 + i - 0.5, ask: 100.0 + i + 0.5, timestamp: Time.current + i)) }
    indicators = engine.for('RELIANCE')
    expect(indicators).to have_key(:sma_20)
    expect(indicators[:sma_20]).to be_a(Numeric)
  end
end
