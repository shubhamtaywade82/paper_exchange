require 'rails_helper'

RSpec.describe Ledger::Ledger, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:trade) { instance_double('PaperExchange::PaperTrade', id: 1, account_id: account_id, symbol: 'NIFTY', side: 'buy', quantity: 10, trade_price: 100.0, trade_type: 'regular') }

  before { create(:account, account_id: account_id) }

  it 'records a trade and creates ledger entries' do
    expect { described_class.record_trade(account_id: account_id, trade: trade) }.to change(LedgerEntry, :count).by(2)
  end
end
