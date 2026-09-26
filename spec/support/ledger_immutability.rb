# Audit N3 (T5.1): db/schema.rb cannot express triggers, so a test
# database built by loading the schema (`bin/rails db:test:prepare` — the
# CI path) lacks the ledger immutability trigger that migration
# 20260926120001 installs into dev/production databases. Re-install it
# from the same shared DDL source (Ledger::Immutability) so the specs
# assert exactly the enforcement production runs. No-op when the
# database was built by real migrations.
#
# before(:suite) — not require time — because rails_helper runs
# maintain_test_schema! (which may reload the schema and drop the
# trigger) AFTER loading spec/support files.
RSpec.configure do |config|
  config.before(:suite) do
    Ledger::Immutability.install! unless Ledger::Immutability.installed?
  end
end
