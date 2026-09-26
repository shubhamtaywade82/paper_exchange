require 'rails_helper'

# assess = the read-only pre-flight for POST /api/strategy/signals: same
# risk gate as submit_order, decide-only (no RiskEvent rows — audit M5).
RSpec.describe Strategy::StrategyEngine, type: :service do
  let(:account_id) { 'ACC-STRATEGY' }
  let(:engine) do
    described_class.new(
      indicator_engine: instance_double('Strategy::IndicatorEngine'),
      market_structure_engine: instance_double('Strategy::MarketStructureEngine')
    )
  end
  let(:signal) do
    Strategy::Signal.new(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy', quantity: 2,
      order_kind: 'market', instrument_type: 'EQUITY', ltp: 2_500.0, context: {}
    )
  end

  before { create(:account, account_id: account_id, margin: 10_000.0, available_balance: 10_000.0) }

  describe '#evaluate (boolean gate, original contract)' do
    it 'returns signal when risk passes' do
      allow(Risk::RiskManager).to receive(:evaluate).and_return([ [ :passed, :vix_gate ], [ :passed, :margin ], nil ])
      expect(engine.evaluate(signal)).to eq(signal)
    end
  end

  describe '#assess' do
    it 'allows a fundable order and reports per-check outcomes' do
      result = engine.assess(signal)

      expect(result[:decision]).to eq('allow')
      expect(result[:rejections]).to eq([])
      expect(result[:checks]).to include('passed')
    end

    it 'rejects with the rejection vocabulary when margin is insufficient' do
      signal.instance_variable_set(:@quantity, 100) # notional 250k on a 10k account

      result = engine.assess(signal)

      expect(result[:decision]).to eq('reject')
      expect(result[:rejections]).to include('MARGIN_REJECTED')
    end

    it 'decides only — never writes RiskEvent rows (audit M5)' do
      expect { engine.assess(signal) }.not_to change(RiskEvent, :count)
    end
  end
end
