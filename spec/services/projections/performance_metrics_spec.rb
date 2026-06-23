require 'rails_helper'

RSpec.describe Projections::PerformanceMetrics, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:metrics) { described_class.new(account_id: account_id) }

  before { create(:account, account_id: account_id, current_equity: 100_000.0) }

  it 'returns current drawdown' do
    expect(metrics.current_drawdown).to be_a(Numeric)
  end

  it 'returns performance snapshot' do
    expect(metrics.snapshot).to have_key(:equity)
    expect(metrics.snapshot).to have_key(:drawdown)
  end
end
