# frozen_string_literal: true

# Audit N3 (T5.1): the ledger's append-only contract was convention only —
# nothing stopped an UPDATE. Installs the database-level trigger (see
# Ledger::Immutability for why the DDL lives in one shared place, and why
# DELETE stays allowed: the operator's POST /api/account/reset wipe).
#
# Referencing the app service from a migration is a conscious trade-off:
# a local copy of the DDL could drift from the spec-support re-install
# path, and a one-shot migration referencing a stable module is the
# smaller risk. If Ledger::Immutability is ever renamed or removed, this
# migration has already run everywhere that matters (and `db:rollback`
# past a data-normalization migration is not a supported flow here).
class EnforceLedgerEntryImmutability < ActiveRecord::Migration[8.1]
  def up
    Ledger::Immutability.install!(connection)
  end

  def down
    Ledger::Immutability.uninstall!(connection)
  end
end
