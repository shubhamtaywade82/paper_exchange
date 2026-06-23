require 'rails_helper'

RSpec.describe Strategy::MarketStructureEngine, type: :service do
  it 'stores and retrieves snapshots' do
    engine = described_class.new
    engine.ingest('RELIANCE', timeframe: '5m', trend: 'up', bos: true)
    snap = engine.snapshot('RELIANCE', timeframe: '5m')
    expect(snap[:trend]).to eq('up')
    expect(snap[:last_bos]).to be true
  end
end
