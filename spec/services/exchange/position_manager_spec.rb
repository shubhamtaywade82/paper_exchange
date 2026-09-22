require 'rails_helper'

RSpec.describe Exchange::PositionManager, type: :service do
  let(:account_id) { 'ACC-TEST' }

  before { create(:account, account_id: account_id) }

  describe '.apply!' do
    it 'creates a position from flat' do
      expect {
        Exchange::PositionManager.apply!(account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 50, avg_price: 100.0)
      }.to change(PaperExchange::PaperPosition, :count).by(1)

      pos = PaperExchange::PaperPosition.last
      expect(pos.side).to eq('long')
      expect(pos.quantity).to eq(50)
    end

    it 'is a no-op for a zero fill quantity' do
      expect {
        Exchange::PositionManager.apply!(account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 0, avg_price: 100.0)
      }.not_to change(PaperExchange::PaperPosition, :count)
    end

    context 'when a position already exists on the same side' do
      before do
        create(:paper_position, account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 50, avg_price: 100.0)
      end

      it 'weighted-averages the entry price and accumulates quantity' do
        Exchange::PositionManager.apply!(account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 50, avg_price: 120.0)
        pos = PaperExchange::PaperPosition.last
        expect(pos.quantity).to eq(100)
        expect(pos.avg_price).to eq(110.0)
      end
    end

    context 'opening a short from flat' do
      it 'stores a positive quantity magnitude, not zero' do
        Exchange::PositionManager.apply!(account_id: account_id, symbol: 'NIFTY', side: :sell, quantity: 30, avg_price: 100.0)

        pos = PaperExchange::PaperPosition.find_by!(account_id: account_id, symbol: 'NIFTY')
        expect(pos.side).to eq('short')
        expect(pos.quantity).to eq(30)
      end
    end

    context 'reducing an existing short' do
      let!(:position) { create(:paper_position, account_id: account_id, symbol: 'NIFTY', side: :short, quantity: 30, avg_price: 100.0) }

      it 'decreases quantity without touching the entry price, and keeps the same row' do
        result = Exchange::PositionManager.apply!(account_id: account_id, symbol: 'NIFTY', side: :buy, quantity: 10, avg_price: 95.0)

        expect(result.id).to eq(position.id)
        expect(result.side).to eq('short')
        expect(result.quantity).to eq(20)
        expect(result.avg_price).to eq(100.0)
      end
    end

    context 'closing a position exactly' do
      let!(:position) { create(:paper_position, account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 30, avg_price: 100.0) }

      it 'zeroes quantity and avg_price' do
        result = Exchange::PositionManager.apply!(account_id: account_id, symbol: 'NIFTY', side: :sell, quantity: 30, avg_price: 110.0)

        expect(result.id).to eq(position.id)
        expect(result.quantity).to eq(0)
        expect(result.avg_price).to eq(0)
      end
    end

    context 'flipping through zero' do
      let!(:position) { create(:paper_position, account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 30, avg_price: 100.0, leverage: 1) }

      it 'flips side in place on the same row, sized to the excess, at the new fill price' do
        result = Exchange::PositionManager.apply!(
          account_id: account_id, symbol: 'NIFTY', side: :sell, quantity: 50, avg_price: 110.0, leverage: 5, margin_type: 'isolated'
        )

        expect(result.id).to eq(position.id) # same row — no destroy/recreate
        expect(result.side).to eq('short')
        expect(result.quantity).to eq(20) # 50 sold - 30 held long = 20 net short
        expect(result.avg_price).to eq(110.0)
        expect(result.leverage).to eq(5)
        expect(result.margin_type).to eq('isolated')
      end
    end

    context 'leverage/margin_type while a position stays open' do
      let!(:position) { create(:paper_position, account_id: account_id, symbol: 'NIFTY', side: :long, quantity: 30, avg_price: 100.0, leverage: 3, margin_type: 'isolated') }

      it 'does not change once a position is open (only when reopening from flat)' do
        result = Exchange::PositionManager.apply!(account_id: account_id, symbol: 'NIFTY', side: :buy, quantity: 10, avg_price: 105.0, leverage: 10, margin_type: 'cross')

        expect(result.leverage).to eq(3)
        expect(result.margin_type).to eq('isolated')
      end
    end

    context 'distinct contracts on the same underlying symbol' do
      it 'does not collide two different option contracts' do
        ce = Exchange::PositionManager.apply!(
          account_id: account_id, symbol: 'NIFTY', side: :buy, quantity: 50, avg_price: 100.0,
          instrument_type: 'OPTIDX', option_type: 'CE', strike_price: 26_000, expiry_date: Date.today + 7
        )
        pe = Exchange::PositionManager.apply!(
          account_id: account_id, symbol: 'NIFTY', side: :buy, quantity: 20, avg_price: 80.0,
          instrument_type: 'OPTIDX', option_type: 'PE', strike_price: 26_000, expiry_date: Date.today + 7
        )

        expect(ce.id).not_to eq(pe.id)
        expect(ce.reload.quantity).to eq(50)
        expect(pe.reload.quantity).to eq(20)
      end

      it 'does not collide a plain equity position with a same-symbol future/option on the same underlying' do
        equity = Exchange::PositionManager.apply!(account_id: account_id, symbol: 'RELIANCE', side: :buy, quantity: 10, avg_price: 2_500.0, instrument_type: 'EQUITY')
        future = Exchange::PositionManager.apply!(account_id: account_id, symbol: 'RELIANCE', side: :buy, quantity: 5, avg_price: 2_510.0, instrument_type: 'FUTSTK')

        expect(equity.id).not_to eq(future.id)
      end
    end
  end
end
