# Prod-hardening (NEW-30, NEW-31): every money table references accounts by
# the string `account_id` column, but the reference was app-layer only —
# MarginLedger.lock_margin! does Account.lock.find_by!(account_id:), which
# raises if the account is missing, but a rogue AR update, a SQL typo, or a
# job running after the account was reset could write rows for a non-existent
# account. The Reconciler would then silently "derive" wallet state from those
# orphan rows, corrupting the trust invariant (wallet == Σ ledger entries).
#
# These FKs make the constraint structural. The reset flow in
# AccountsController#reset already deletes children before parents in the
# correct order (funding_payments → trades → positions → orders → ledger),
# so NO ACTION (the default) is safe: an account can never be deleted while it
# still has money rows, and orphan writes fail at the DB rather than later.
#
# IMPORTANT: the `accounts` table uses a string `account_id` column (not the
# bigint `id` PK) as the business key. The FK must reference `account_id` on
# BOTH sides via `primary_key: :account_id` — otherwise Postgres raises a
# DatatypeMismatch (varchar vs bigint).
#
# Run on a clean DB, or backfill/repair orphan rows first:
#   SELECT account_id FROM ledger_entries
#   WHERE account_id NOT IN (SELECT account_id FROM accounts);
class AddAccountForeignKeys < ActiveRecord::Migration[8.1]
  def up
    add_foreign_key :ledger_entries, :accounts, column: :account_id, primary_key: :account_id
    add_foreign_key :paper_exchange_orders, :accounts, column: :account_id, primary_key: :account_id
    add_foreign_key :paper_exchange_positions, :accounts, column: :account_id, primary_key: :account_id
    add_foreign_key :risk_events, :accounts, column: :account_id, primary_key: :account_id
    add_foreign_key :funding_payments, :accounts, column: :account_id, primary_key: :account_id
  end

  def down
    remove_foreign_key :funding_payments, :accounts, column: :account_id
    remove_foreign_key :risk_events, :accounts, column: :account_id
    remove_foreign_key :paper_exchange_positions, :accounts, column: :account_id
    remove_foreign_key :paper_exchange_orders, :accounts, column: :account_id
    remove_foreign_key :ledger_entries, :accounts, column: :account_id
  end
end
