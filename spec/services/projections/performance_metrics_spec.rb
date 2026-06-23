require 'rails_helper'

RSpec.describe Projections::PerformanceMetrics, type: :service do
  let(:account_id) { 'ACC-TEST' }

  before { create(:account, account_id: account_id, current_equity: 100_000.0) }

  it 'returns current drawdown' do
    metrics = described_class.for(account_id)
    expect(metrics[:max_drawdown]).to be_a(Numeric)
  end

  it 'returns performance snapshot' do
    metrics = described_class.for(account_id)
    expect(metrics).to have_key(:unrealized_pnl)
    expect(metrics).to have_key(:realized_pnl)
  end
end
