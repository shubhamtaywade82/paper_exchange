class LedgerEntry < ApplicationRecord
  self.table_name = "ledger_entries"

  validates :account_id, presence: true
  # Audit N2 (T5.2): event types are SCREAMING_SNAKE_CASE ("TRADE",
  # "MARGIN_LOCKED", "MARGIN_UNLOCKED", "FEE", "REALIZED_PNL",
  # "FUNDING_FEE", "ADJUSTMENT"). The legacy lowercase "trade" spelling
  # was normalized in migration 20260926120000; this format guard keeps
  # the vocabulary from forking again.
  validates :event_type, presence: true,
    format: {
      with: /\A[A-Z][A-Z0-9_]*\z/,
      message: "must be SCREAMING_SNAKE_CASE (e.g. TRADE, MARGIN_LOCKED)"
    }
  validates :debit, numericality: { greater_than_or_equal_to: 0 }
  validates :credit, numericality: { greater_than_or_equal_to: 0 }
  validates :occurred_at, presence: true

  # Audit N3 (T5.1): the ledger is the append-only source of truth the
  # Reconciler replays — history must never be edited. Once persisted, a
  # row is readonly: `update`, `update_columns`-style writes and
  # `destroy` raise ActiveRecord::ReadOnlyRecord instead of silently
  # rewriting the past. Belt-and-braces: a Postgres trigger installed by
  # migration 20260926120001 (see Ledger::Immutability) also blocks
  # UPDATE for anything that bypasses ActiveRecord. DELETE stays allowed
  # for the operator's explicit POST /api/account/reset wipe.
  def readonly?
    persisted?
  end
end
