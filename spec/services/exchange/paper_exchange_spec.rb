require 'rails_helper'

RSpec.describe Exchange::PaperExchange, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:exchange) { described_class.new(account_id: account_id) }

  before do
    create(:account, account_id: account_id)
  end

  describe '#submit_order' do
    let(:valid_attrs) do
      {
        account_id: account_id,
        symbol: 'RELIANCE',
        side: 'buy',
        quantity: 10,
        order_kind: 'market',
        instrument_type: 'EQUITY',
        price: nil
      }
    end

    it 'creates a paper order and returns result' do
      expect { exchange.submit_order(valid_attrs) }.to change(PaperExchange::PaperOrder, :count).by(1)
      order = PaperExchange::PaperOrder.last
      expect(order.status).to eq('filled')
    end

    context 'with invalid order' do
      let(:invalid_attrs) { valid_attrs.merge(side: 'invalid_side') }
      it 'raises and rejects order' do
        expect { exchange.submit_order(invalid_attrs) }.to raise_error(RuntimeError)
        order = PaperExchange::PaperOrder.last
        expect(order).to be_present
        expect(order.status).to eq('rejected')
      end
    end
  end

  describe '#cancel_order' do
    let(:order) { create(:paper_order, account_id: account_id, status: :open) }
    it 'cancels the order' do
      exchange.cancel_order(order.id)
      expect(order.reload.status).to eq('cancelled')
    end
  end

  describe '#market_event' do
    let(:event) { instance_double('MarketData::MarketEvent', symbol: 'NIFTY', bid: 100, ask: 101, ltp: 100.5, depth: nil, timestamp: Time.current) }
    it 'applies snapshot to order book' do
      expect { exchange.market_event(event) }.not_to raise_error
    end
  end
end
