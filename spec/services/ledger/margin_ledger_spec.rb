require 'rails_helper'

RSpec.describe Ledger::MarginLedger, type: :service do
  let(:account) { create(:account, account_id: 'ACC-MARGIN', margin: 10_000.0) }

  describe '.lock_margin!' do
    it 'moves funds from available_balance into locked_margin' do
      described_class.lock_margin!(account_id: account.account_id, amount: 4_000.0)
      account.reload

      expect(account.available_balance).to eq(6_000.0)
      expect(account.locked_margin).to eq(4_000.0)
    end

    it 'writes an immutable MARGIN_LOCKED ledger entry' do
      expect {
        described_class.lock_margin!(account_id: account.account_id, amount: 1_000.0, reference_id: 'ORDER-1')
      }.to change(LedgerEntry, :count).by(1)

      entry = LedgerEntry.last
      expect(entry.event_type).to eq('MARGIN_LOCKED')
      expect(entry.debit).to eq(1_000.0)
      expect(entry.reference_id).to eq('ORDER-1')
    end

    it 'raises InsufficientMarginError instead of overdrawing available_balance' do
      expect {
        described_class.lock_margin!(account_id: account.account_id, amount: 50_000.0)
      }.to raise_error(Ledger::InsufficientMarginError)

      account.reload
      expect(account.available_balance).to eq(10_000.0)
      expect(account.locked_margin).to eq(0.0)
    end

    it 'is a no-op for a zero amount' do
      expect {
        described_class.lock_margin!(account_id: account.account_id, amount: 0)
      }.not_to change(LedgerEntry, :count)
    end

    it 'rejects a negative amount' do
      expect {
        described_class.lock_margin!(account_id: account.account_id, amount: -1)
      }.to raise_error(ArgumentError)
    end
  end

  describe '.unlock_margin!' do
    before { described_class.lock_margin!(account_id: account.account_id, amount: 4_000.0) }

    it 'moves funds back from locked_margin into available_balance' do
      described_class.unlock_margin!(account_id: account.account_id, amount: 1_500.0)
      account.reload

      expect(account.available_balance).to eq(7_500.0)
      expect(account.locked_margin).to eq(2_500.0)
    end

    it 'caps the release at whatever is actually locked' do
      described_class.unlock_margin!(account_id: account.account_id, amount: 999_999.0)
      account.reload

      expect(account.locked_margin).to eq(0.0)
      expect(account.available_balance).to eq(10_000.0)
    end

    it 'writes an immutable MARGIN_UNLOCKED ledger entry' do
      expect {
        described_class.unlock_margin!(account_id: account.account_id, amount: 500.0)
      }.to change(LedgerEntry, :count).by(1)

      expect(LedgerEntry.last.event_type).to eq('MARGIN_UNLOCKED')
    end
  end

  describe '.deduct_fee!' do
    it 'deducts fee from available_balance and creates a FEE ledger entry' do
      expect {
        described_class.deduct_fee!(account_id: account.account_id, amount: 2.4, reference_id: 'TRADE-1')
      }.to change(LedgerEntry, :count).by(1)

      account.reload
      expect(account.available_balance).to eq(9_997.6)
      expect(LedgerEntry.last.event_type).to eq('FEE')
      expect(LedgerEntry.last.debit).to eq(2.4)
    end
  end

  describe '.credit_realized_pnl!' do
    it 'adds profit to available_balance and creates REALIZED_PNL credit entry' do
      expect {
        described_class.credit_realized_pnl!(account_id: account.account_id, amount: 300.0, reference_id: 'TRADE-2')
      }.to change(LedgerEntry, :count).by(1)

      account.reload
      expect(account.available_balance).to eq(10_300.0)
      expect(LedgerEntry.last.event_type).to eq('REALIZED_PNL')
      expect(LedgerEntry.last.credit).to eq(300.0)
    end
  end
end
