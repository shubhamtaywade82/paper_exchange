require 'rails_helper'

RSpec.describe Strategy::MarketStructureEngine, type: :service do
  let(:engine) { described_class.new }

  it 'stores and retrieves snapshots' do
    engine.ingest('RELIANCE', timeframe: '5m', trend: 'up', bos: true)
    snap = engine.snapshot('RELIANCE', timeframe: '5m')
    expect(snap[:trend]).to eq('up')
    expect(snap[:last_bos]).to be true
  end

  it 'persists rows (DB-backed, not in-memory)' do
    expect {
      engine.ingest('BTCUSDT', timeframe: '15m', trend: 'bullish', choch: true,
                    bullish_fvg_count: 2, bearish_fvg_count: 1,
                    liquidity_sweep: 'sell_side', order_block: 'bullish_ob',
                    premium_discount: 'premium')
    }.to change(MarketStructureSnapshot, :count).by(1)
  end

  it 'normalizes the symbol to upper case' do
    engine.ingest('btcusdt', timeframe: '5m')
    expect(engine.snapshot('BTCUSDT')[:symbol]).to eq('BTCUSDT')
  end

  it 'snapshot returns the newest row per (symbol, timeframe)' do
    engine.ingest('BTCUSDT', timeframe: '5m', trend: 'bearish', as_of: 1.hour.ago)
    engine.ingest('BTCUSDT', timeframe: '5m', trend: 'bullish', as_of: 5.minutes.ago)

    expect(engine.snapshot('BTCUSDT', timeframe: '5m')[:trend]).to eq('bullish')
  end

  it 'keeps timeframes independent' do
    engine.ingest('BTCUSDT', timeframe: '1m', trend: 'bearish')
    engine.ingest('BTCUSDT', timeframe: '5m', trend: 'bullish')

    expect(engine.snapshot('BTCUSDT', timeframe: '1m')[:trend]).to eq('bearish')
    expect(engine.snapshot('BTCUSDT', timeframe: '5m')[:trend]).to eq('bullish')
  end

  it 'latest returns the newest snapshot per symbol' do
    engine.ingest('BTCUSDT', timeframe: '5m', trend: 'bullish', as_of: 5.minutes.ago)
    engine.ingest('BTCUSDT', timeframe: '5m', trend: 'bearish', as_of: 1.minute.ago)
    engine.ingest('ETHUSDT', timeframe: '5m', trend: 'range')

    latest = engine.latest(timeframe: '5m')

    expect(latest.map { |s| s[:symbol] }).to eq(%w[BTCUSDT ETHUSDT])
    expect(latest.first[:trend]).to eq('bearish') # newest wins
  end
end
