# frozen_string_literal: true

# Audit N2 (T5.2): LedgerEntry.event_type shipped two conventions — the
# legacy lowercase "trade" (written by Ledger::Ledger.record_trade) and
# SCREAMING_SNAKE_CASE everywhere else ("MARGIN_LOCKED", "MARGIN_UNLOCKED",
# "FEE", "REALIZED_PNL", "FUNDING_FEE", "ADJUSTMENT"). The model now
# enforces SCREAMING_SNAKE_CASE, so existing rows are normalized once
# here, BEFORE the immutability trigger lands (migration 20260926120001
# blocks UPDATE on this table).
#
# Data-only fix, idempotent, no schema change. The down migration is a
# deliberate no-op: re-lowercasing event types would violate the model's
# format validation and fork the event vocabulary again.
class NormalizeLedgerEntryEventType < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE ledger_entries
      SET event_type = UPPER(event_type)
      WHERE event_type <> UPPER(event_type)
    SQL
  end

  def down
    # Intentionally irreversible (see class comment).
  end
end
