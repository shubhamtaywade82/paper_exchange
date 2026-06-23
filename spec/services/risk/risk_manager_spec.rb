require 'rails_helper'

RSpec.describe Risk::RiskManager, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:signal) { instance_double('Strategy::Signal', to_h: { symbol: 'NIFTY', side: 'buy', quantity: 10 }) }

  before { create(:account, account_id: account_id) }

  describe '.evaluate' do
    context 'when all validators pass' do
      before do
        allow(Risk::VixGateValidator).to receive(:new).and_return(double(evaluate: :passed))
        allow(Risk::MarginValidator).to receive(:new).and_return(double(evaluate: :passed))
        allow(Risk::MaxDrawdownValidator).to receive(:new).and_return(double(evaluate: :passed))
        allow(Risk::PositionLimitValidator).to receive(:new).and_return(double(evaluate: :passed))
      end

      it 'returns passed status' do
        result, events = described_class.evaluate(account_id: account_id, signal: signal)
        expect(events).to be_nil
        expect(result).to be_an(Array)
      end
    end
  end
end
