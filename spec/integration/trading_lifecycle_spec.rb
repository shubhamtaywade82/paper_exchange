require 'rails_helper'

RSpec.describe 'Exchange trading lifecycle', type: :integration do
  let(:account_id) { 'ACC-LIFECYCLE' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }

  before { create(:account, account_id: account_id) }

  context 'happy path' do
    let(:attrs) do
      {
        account_id: account_id,
        symbol: 'RELIANCE',
        side: 'buy',
        quantity: 10,
        order_kind: 'market',
        instrument_type: 'EQUITY'
      }
    end

    it 'submits, fills, and records trade + ledger entries' do
      expect { exchange.submit_order(attrs) }.to change(PaperExchange::PaperOrder, :count).by(1)
                                                    .and change(PaperExchange::PaperTrade, :count).by(1)
                                                    .and change(LedgerEntry, :count).by(1)
                                                    .and change(PaperExchange::PaperPosition, :count).by(1)

      order = PaperExchange::PaperOrder.last
      expect(order.status).to eq('filled')
    end
  end

  context 'risk failure path' do
    before do
      allow(Risk::RiskManager).to receive(:evaluate).and_return([ [], [ :MAX_DRAWDOWN_REJECTED ] ])
    end

    let(:attrs) do
      {
        account_id: account_id,
        symbol: 'NIFTY',
        side: 'buy',
        quantity: 1,
        order_kind: 'market',
        instrument_type: 'FUTIDX'
      }
    end

    it 'rejects the order' do
      expect { exchange.submit_order(attrs) }.to raise_error(Exchange::PaperExchange::RiskCheckFailedError, /Risk check failed/)
      order = PaperExchange::PaperOrder.last
      expect(order.status).to eq('rejected')
    end

    # M5 regression guard: rejection events used to be created inside the
    # order transaction and rolled back with it — the rejection history
    # /api/risk_events exists to serve was never written.
    it 'persists the *_REJECTED risk events after the rollback' do
      expect { exchange.submit_order(attrs) }.to raise_error(Exchange::PaperExchange::RiskCheckFailedError)

      events = RiskEvent.where(account_id: account_id, event_type: 'MAX_DRAWDOWN_REJECTED')
      expect(events.count).to eq(1)
      expect(events.last.details['signal']['symbol']).to eq('NIFTY')
      expect(events.last.details['rejection']).to include('MAX_DRAWDOWN_REJECTED')
    end
  end
end
