require 'rails_helper'

RSpec.describe Exchange::PositionManager, type: :service do
  let(:account_id) { 'ACC-TEST' }

  before { create(:account, account_id: account_id) }

  describe '.apply!' do
    it 'creates or updates a position' do
      expect {
        Exchange::PositionManager.apply!(account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 50, avg_price: 100.0)
      }.to change(PaperExchange::PaperPosition, :count).by(1)
    end

    context 'when position exists' do
      before do
        create(:paper_position, account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 50, avg_price: 100.0)
      end

      it 'recalculates average price' do
        Exchange::PositionManager.apply!(account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 50, avg_price: 120.0)
        pos = PaperExchange::PaperPosition.last
        expect(pos.quantity).to eq(100)
        expect(pos.avg_price).to eq(110.0)
      end
    end
  end
end
