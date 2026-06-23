class LedgerEntry < ApplicationRecord
  self.table_name = "ledger_entries"

  validates :account_id, presence: true
  validates :event_type, presence: true
  validates :debit, numericality: { greater_than_or_equal_to: 0 }
  validates :credit, numericality: { greater_than_or_equal_to: 0 }
  validates :occurred_at, presence: true
end
