# Rebuilds account wallet state from the ledger and the liquidation engine's
# in-memory position cache on every boot, so a process restart (deploy,
# crash, Kamal rollout) never leaves a stale cached balance or drops an open
# leveraged position from liquidation monitoring. See Ledger::Reconciler.
#
# Skipped in test: specs manage their own isolated data per example, and
# running this against a database that migrations haven't touched yet (e.g.
# during `db:create`) would raise before setup finishes.
#
# Prod-hardening (NEW-8): in production a failed reconcile means the wallet
# state no longer equals Σ ledger entries — the system's core trust invariant
# (prd §6.1). Booting with stale wallet state is worse than not booting (a
# silently wrong `available_balance` lets orders through that should not
# pass), so production re-raises and fails the deploy. Dev/test still swallows
# the error so `db:create` / first-boot flows don't break.
Rails.application.config.after_initialize do
  next if Rails.env.test?

  begin
    next unless ActiveRecord::Base.connection.table_exists?("accounts")

    Ledger::Reconciler.call
  rescue => e
    if Rails.env.production?
      raise "Boot reconciliation failed — refusing to start with potentially " \
            "stale wallet state (#{e.class}: #{e.message}). Inspect the ledger " \
            "and re-run Ledger::Reconciler.call once the cause is resolved."
    end
    Rails.logger.error("[Reconciler] boot reconciliation failed: #{e.message}")
  end
end
