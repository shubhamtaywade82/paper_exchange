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

  describe 'non-crypto sell netting (audit S5/T3.7)' do
    def sell_trade(price:, quantity:, total_charges:)
      instance_double('PaperExchange::PaperTrade',
        id: 99, paper_order: order, side: 'sell', quantity: quantity, price: price,
        traded_at: Time.current, charges: {}, paper_order_id: 1,
        total_charges: total_charges)
    end

    it 'nets charges against proceeds when proceeds cover them' do
      described_class.record_trade(account_id: account_id, trade: sell_trade(price: 100.0, quantity: 10, total_charges: 50.0))

      entry = LedgerEntry.find_by!(reference_id: '99')
      expect(entry.credit.to_f).to eq(950.0)
      expect(entry.debit.to_f).to eq(0.0)
    end

    it 'posts the uncovered remainder as a debit when charges exceed proceeds (cheap option close)' do
      described_class.record_trade(account_id: account_id, trade: sell_trade(price: 1.0, quantity: 10, total_charges: 50.0))

      entry = LedgerEntry.find_by!(reference_id: '99')
      expect(entry.credit.to_f).to eq(0.0)
      expect(entry.debit.to_f).to eq(40.0)
    end
  end

  describe '.compute_realized_pnl (audit S4/T3.6)' do
    it 'raises when the underlying query fails instead of silently reporting 0.0' do
      allow(LedgerEntry).to receive(:where).and_raise(ActiveRecord::ActiveRecordError, 'connection gone')

      expect { described_class.compute_realized_pnl(account_id) }.to raise_error(ActiveRecord::ActiveRecordError, 'connection gone')
    end
  end
end
