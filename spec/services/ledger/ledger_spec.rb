require 'rails_helper'

RSpec.describe Ledger::Ledger, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:order) { instance_double('PaperExchange::PaperOrder', id: 1, symbol: 'NIFTY') }
  let(:trade) { instance_double('PaperExchange::PaperTrade', id: 1, paper_order: order, side: 'buy', quantity: 10, price: 100.0, traded_at: Time.current, charges: {}, paper_order_id: 1) }

  before { create(:account, account_id: account_id) }

  it 'records a trade and creates ledger entries' do
    expect { described_class.record_trade(account_id: account_id, trade: trade) }.to change(LedgerEntry, :count).by(1)
  end

  it 'refreshes the cached equity from the wallet, so fees deducted from available_balance are included' do
    Account.find_by!(account_id: account_id).update!(available_balance: 499_997.4, locked_margin: 0.0)

    described_class.refresh_cached_equity!(account_id)

    expect(Account.find_by!(account_id: account_id).current_equity.to_f).to eq(499_997.4)
  end
end
