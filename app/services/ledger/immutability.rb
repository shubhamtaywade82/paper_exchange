module Ledger
  # Database-level enforcement of the ledger's append-only contract (audit
  # N3 / T5.1). `LedgerEntry#readonly?` guards every ActiveRecord path;
  # this trigger is the belt-and-braces that also blocks UPDATEs which
  # bypass ActiveRecord entirely (update_all, hand-written SQL, a stray
  # psql session).
  #
  # Single source of truth for the trigger DDL so the two installation
  # paths can never drift apart:
  #   * migration 20260926120001 installs it into dev/production
  #     databases (bin/rails db:migrate);
  #   * spec/support/ledger_immutability.rb re-installs it on test
  #     databases built by loading db/schema.rb (`bin/rails
  #     db:test:prepare`) — the Ruby schema format cannot express
  #     triggers, so a schema-loaded test DB would otherwise silently
  #     lack the enforcement the specs assert.
  #
  # DELETE is deliberately NOT blocked: POST /api/account/reset (the
  # operator's explicit five-table wipe) deletes ledger rows via
  # delete_all, and there is no other legitimate deleter. UPDATE has no
  # legitimate caller at all — corrections are posted as new compensating
  # entries (see Ledger::Reconciler), never edits of history.
  module Immutability
    TRIGGER_NAME = "ledger_entries_no_update"
    FUNCTION_NAME = "ledger_entries_block_update"
    # Arbitrary constant identifying this install in Postgres advisory
    # locks (prevents a DROP/CREATE race between two boots of the
    # spec-support shim).
    INSTALL_LOCK_ID = 72_309_260

    module_function

    def install!(connection = ActiveRecord::Base.connection)
      with_install_lock(connection) do
        connection.execute(<<~SQL)
          CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
          RETURNS trigger AS $$
          BEGIN
            RAISE EXCEPTION 'ledger_entries is append-only (audit N3): UPDATE is blocked at the database level'
              USING ERRCODE = 'P0001',
                    HINT = 'Post a compensating entry instead of editing history (see Ledger::Reconciler).';
          END;
          $$ LANGUAGE plpgsql;
        SQL

        connection.execute(<<~SQL)
          DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON #{LedgerEntry.table_name};
          CREATE TRIGGER #{TRIGGER_NAME}
          BEFORE UPDATE ON #{LedgerEntry.table_name}
          FOR EACH ROW EXECUTE FUNCTION #{FUNCTION_NAME}();
        SQL
      end
    end

    def uninstall!(connection = ActiveRecord::Base.connection)
      with_install_lock(connection) do
        connection.execute("DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON #{LedgerEntry.table_name}")
        connection.execute("DROP FUNCTION IF EXISTS #{FUNCTION_NAME}()")
      end
    end

    def installed?(connection = ActiveRecord::Base.connection)
      connection.select_value(
        "SELECT 1 FROM pg_trigger WHERE tgname = #{connection.quote(TRIGGER_NAME)}"
      ).present?
    end

    def with_install_lock(connection)
      connection.execute("SELECT pg_advisory_lock(#{INSTALL_LOCK_ID})")
      yield
    ensure
      connection.execute("SELECT pg_advisory_unlock(#{INSTALL_LOCK_ID})")
    end
  end
end
