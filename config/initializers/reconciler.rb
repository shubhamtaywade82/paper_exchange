# Rebuilds account wallet state from the ledger and the liquidation engine's
# in-memory position cache on every boot, so a process restart (deploy,
# crash, Kamal rollout) never leaves a stale cached balance or drops an open
# leveraged position from liquidation monitoring. See Ledger::Reconciler.
#
# Skipped in test: specs manage their own isolated data per example, and
# running this against a database that migrations haven't touched yet (e.g.
# during `db:create`) would raise before setup finishes.
Rails.application.config.after_initialize do
  next if Rails.env.test?

  begin
    next unless ActiveRecord::Base.connection.table_exists?("accounts")

    Ledger::Reconciler.call
  rescue => e
    Rails.logger.error("[Reconciler] boot reconciliation failed: #{e.message}")
  end
end
