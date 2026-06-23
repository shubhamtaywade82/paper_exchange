require 'rails_helper'

RSpec.describe Exchange::FillEngine, type: :service do
  let(:fill_engine) { described_class.new(slippage: Exchange::SlippageEngine.new) }
  let(:account) { create(:account) }
  let(:order) { create(:paper_order, account_id: account.account_id, status: :open, quantity: 100, filled_quantity: 0) }
  let(:snapshot) { { bid: 100, ask: 101, ltp: 100.5 } }

  describe '#fill' do
    it 'returns fill quantity, price, and trade' do
      qty, price, trade = fill_engine.fill(order, market_snapshot: snapshot, instrument_type: 'EQUITY', quantity: 50)
      expect(qty).to eq(50)
      expect(price).to be_a(Numeric)
      expect(trade).to be_a(PaperExchange::PaperTrade)
    end
  end
end
