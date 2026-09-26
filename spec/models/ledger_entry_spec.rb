require 'rails_helper'

# Audit N2 (T5.2) — event_type vocabulary is SCREAMING_SNAKE_CASE, one
# convention, enforced at the model boundary.
# Audit N3 (T5.1) — the ledger is append-only: persisted rows cannot be
# updated or destroyed. Two layers:
#   * ActiveRecord layer: readonly? raises ReadOnlyRecord (below);
#   * database layer: a BEFORE UPDATE trigger blocks even raw SQL
#     (installed by migration 20260926120001 in dev/prod, and by
#     spec/support/ledger_immutability.rb on schema-loaded test DBs).
RSpec.describe LedgerEntry, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:account_id) }
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:occurred_at) }
    it { is_expected.to validate_numericality_of(:debit).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:credit).is_greater_than_or_equal_to(0) }
  end

  describe 'event_type format (audit N2)' do
    it 'creates a row with a SCREAMING_SNAKE_CASE event type' do
      expect { create(:ledger_entry, event_type: 'TRADE') }.to change(described_class, :count).by(1)
    end

    it 'rejects the legacy lowercase "trade" spelling' do
      entry = build(:ledger_entry, event_type: 'trade')
      expect(entry).not_to be_valid
      expect(entry.errors[:event_type]).to include(/SCREAMING_SNAKE_CASE/)
    end

    it 'rejects mixed case' do
      expect(build(:ledger_entry, event_type: 'MarginLocked')).not_to be_valid
    end
  end

  describe 'append-only enforcement (audit N3)' do
    let!(:entry) { create(:ledger_entry, event_type: 'TRADE', credit: 100.0) }

    it 'still creates new rows freely' do
      expect { create(:ledger_entry, event_type: 'FEE') }.to change(described_class, :count).by(1)
    end

    it 'raises ActiveRecord::ReadOnlyRecord on update' do
      expect { entry.update!(credit: 999.0) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'raises ActiveRecord::ReadOnlyRecord on destroy' do
      expect { entry.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'blocks raw SQL UPDATE at the database level (belt-and-braces trigger)' do
      expect {
        ActiveRecord::Base.connection.execute(
          "UPDATE ledger_entries SET credit = 999 WHERE id = #{entry.id}"
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /append-only/)
    end

    it 'still allows DELETE — the operator account-reset wipe path (AccountsController#reset uses delete_all)' do
      expect {
        described_class.where(id: entry.id).delete_all
      }.to change(described_class, :count).by(-1)
    end
  end
end
