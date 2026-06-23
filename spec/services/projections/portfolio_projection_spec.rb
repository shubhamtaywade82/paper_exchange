require 'rails_helper'

RSpec.describe Projections::PortfolioProjection, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:projection) { described_class.new(account_id: account_id) }

  before { create(:account, account_id: account_id, current_equity: 100_000.0) }

  it 'returns portfolio summary' do
    summary = projection.summary
    expect(summary).to have_key(:total_positions)
    expect(summary).to have_key(:open_positions)
    expect(summary).to have_key(:margin_utilized)
  end
end
