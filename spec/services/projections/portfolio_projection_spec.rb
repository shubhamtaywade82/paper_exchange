require 'rails_helper'

RSpec.describe Projections::PortfolioProjection, type: :service do
  let(:account_id) { 'ACC-TEST' }

  before { create(:account, account_id: account_id, current_equity: 100_000.0) }

  it 'returns portfolio summary' do
    summary = described_class.summary(account_id)
    expect(summary).to have_key(:positions_count)
    expect(summary).to have_key(:equity)
    expect(summary[:equity]).to eq(100_000.0)
  end
end
