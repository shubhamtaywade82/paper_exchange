require 'rails_helper'

RSpec.describe Projections::PositionProjection, type: :service do
  let(:account_id) { 'ACC-TEST' }

  before do
    create(:account, account_id: account_id)
    create(:paper_position, account_id: account_id, symbol: 'NIFTY', side: 'long', quantity: 50, avg_price: 100.0, current_price: 110.0)
  end

  it 'returns position list with pnl' do
    positions = described_class.for_account(account_id)
    expect(positions).to be_an(Array)
    expect(positions.first[:unrealized_pnl]).to eq(500.0)
  end
end
