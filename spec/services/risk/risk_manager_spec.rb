require 'rails_helper'

# Audit M5 (T2.3): the risk gate must FAIL CLOSED (a raising validator
# rejects the order — it may never wave one through), and it only decides:
# persistence of rejection events lives in PaperExchange#submit_order's
# post-rollback rescue path (covered in trading_lifecycle_spec).
RSpec.describe Risk::RiskManager, type: :service do
  let(:account_id) { 'ACC-RISK-MANAGER' }
  let(:signal) do
    Strategy::Signal.new(
      account_id: account_id,
      symbol: 'RELIANCE',
      side: 'buy',
      quantity: 2,
      order_kind: 'market',
      instrument_type: 'EQUITY',
      ltp: 2_500.0,
      context: {}
    )
  end

  before { create(:account, account_id: account_id, margin: 10_000.0, available_balance: 10_000.0) }

  describe '.evaluate with real validators' do
    it 'passes a normal order' do
      result, events = described_class.evaluate(account_id: account_id, signal: signal)

      expect(events).to be_nil
      expect(result).to be_an(Array)
      expect(result).to include(:passed)
    end

    it 'returns the rejection symbols when a validator trips' do
      stub_const('Risk::MarginValidator::MAX_POSITION_VALUE', 1.0)

      result, events = described_class.evaluate(account_id: account_id, signal: signal)

      expect(events).to include(:MARGIN_REJECTED)
      expect(result).to eq([])
    end

    it 'fails CLOSED when a validator raises — RISK_EVALUATION_ERROR_REJECTED, never a silent pass' do
      allow_any_instance_of(Risk::MarginValidator).to receive(:evaluate).and_raise(NoMethodError, 'validator bug')

      result, events = described_class.evaluate(account_id: account_id, signal: signal)

      expect(events).to eq([ :RISK_EVALUATION_ERROR_REJECTED ])
      expect(result).to eq([])
    end
  end
end
