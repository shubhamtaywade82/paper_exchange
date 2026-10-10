require 'rails_helper'

# Prod-hardening (NEW-21): VixGateValidator is the only risk validator with no
# spec coverage. It gates trading on India VIX (high VIX = high implied vol =
# wider stops needed = reject until calm). The validator runs inside the risk
# pipeline but only ACTIVATES when the caller passes context[:vix] — which is
# why it was easy to leave untested. These specs pin both the active-reject
# path and the inert no-context path so a future refactor can't silently flip
# the gate open or make it reject unconditionally.
RSpec.describe Risk::VixGateValidator, type: :service do
  let(:account_id) { 'ACC-VIX' }
  let(:base_attrs) do
    { account_id: account_id, symbol: 'NIFTY', side: 'buy', quantity: 50,
      order_kind: 'market', instrument_type: 'OPTIDX', ltp: 100.0 }
  end

  def signal_with(vix)
    Strategy::Signal.new(**base_attrs, context: { vix: vix })
  end

  before { create(:account, account_id: account_id, margin: 100_000.0) }

  it 'passes when VIX is below the default threshold (20.0)' do
    validator = described_class.new
    expect(validator.evaluate(account_id, signal_with(14.2))).to eq(:passed)
  end

  it 'passes when VIX equals the threshold (inclusive boundary)' do
    validator = described_class.new
    expect(validator.evaluate(account_id, signal_with(20.0))).to eq(:passed)
  end

  it 'rejects when VIX exceeds the threshold' do
    validator = described_class.new
    expect(validator.evaluate(account_id, signal_with(25.5))).to eq(:VIX_REJECTED)
  end

  it 'is inert (passes) when no VIX is supplied in context' do
    signal = Strategy::Signal.new(**base_attrs, context: {})
    validator = described_class.new
    expect(validator.evaluate(account_id, signal)).to eq(:passed)
  end

  it 'respects a custom max_vix threshold' do
    validator = described_class.new(max_vix: 30.0)
    expect(validator.evaluate(account_id, signal_with(28.0))).to eq(:passed)
    expect(validator.evaluate(account_id, signal_with(31.0))).to eq(:VIX_REJECTED)
  end
end
