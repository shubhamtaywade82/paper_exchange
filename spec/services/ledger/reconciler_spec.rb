require 'rails_helper'

RSpec.describe Ledger::Reconciler, type: :service do
  let(:account) { create(:account, account_id: 'ACC-RECONCILE', margin: 50_000.0) }

  describe '.reconcile_account!' do
    it 'is a no-op for a freshly created, untouched account' do
      expect { described_class.reconcile_account!(account) }.not_to change(LedgerEntry, :count)
    end

    it 'is a no-op when the cached wallet matches the ledger-derived one' do
      Ledger::MarginLedger.lock_margin!(account_id: account.account_id, amount: 5_000.0)
      account.reload

      expect { described_class.reconcile_account!(account) }.not_to change(LedgerEntry, :count)
    end

    it 'corrects drift and posts a visible ADJUSTMENT entry' do
      Ledger::MarginLedger.lock_margin!(account_id: account.account_id, amount: 5_000.0)
      account.reload
      # Simulate a cache that fell out of sync with the ledger (e.g. a crash
      # mid-update) without going through MarginLedger.
      account.update_columns(available_balance: 40_000.0, locked_margin: 10_000.0)

      expect {
        described_class.reconcile_account!(account)
      }.to change(LedgerEntry, :count).by(1)

      entry = LedgerEntry.last
      expect(entry.event_type).to eq('ADJUSTMENT')

      account.reload
      expect(account.available_balance).to eq(45_000.0) # margin(50k) - locked(5k)
      expect(account.locked_margin).to eq(5_000.0)
    end
  end

  describe '.call' do
    it 'reconciles every account and refreshes the liquidation cache' do
      drifted = create(:account, account_id: 'ACC-DRIFT', margin: 20_000.0)
      drifted.update_columns(available_balance: 1_000.0, locked_margin: 19_000.0)

      expect(Risk::LiquidationEngine).to receive(:refresh_cache!)
      described_class.call

      drifted.reload
      expect(drifted.available_balance).to eq(20_000.0)
      expect(drifted.locked_margin).to eq(0.0)
    end
  end
end
