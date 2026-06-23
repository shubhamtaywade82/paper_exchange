require 'rails_helper'

RSpec.describe Strategy::StrategyEngine, type: :service do
  it 'returns signal when risk passes' do
    allow(Risk::RiskManager).to receive(:evaluate).and_return([:passed, []])
    engine = described_class.new(indicator_engine: instance_double('Strategy::IndicatorEngine'), market_structure_engine: instance_double('Strategy::MarketStructureEngine'))
    signal = Strategy::Signal.new(account_id: 'ACC', symbol: 'RELIANCE', side: 'buy', quantity: 1, order_kind: 'market', instrument_type: 'EQUITY')
    expect(engine.evaluate(signal)).to eq(signal)
  end
end
