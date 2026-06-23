require 'rails_helper'

RSpec.describe Ledger::Ledger, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:order) { instance_double('PaperExchange::PaperOrder', id: 1, symbol: 'NIFTY') }
  let(:trade) { instance_double('PaperExchange::PaperTrade', id: 1, paper_order: order, side: 'buy', quantity: 10, price: 100.0, traded_at: Time.current, charges: {}, paper_order_id: 1) }

  before { create(:account, account_id: account_id) }

  it 'records a trade and creates ledger entries' do
    expect { described_class.record_trade(account_id: account_id, trade: trade) }.to change(LedgerEntry, :count).by(2)
  end
end
