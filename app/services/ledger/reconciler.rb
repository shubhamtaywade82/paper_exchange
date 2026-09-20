module Ledger
  # Rebuilds each account's wallet state (`available_balance` /
  # `locked_margin`) from the append-only LedgerEntry stream — the actual
  # source of truth — and corrects any drift from the cached Account columns
  # with a visible ADJUSTMENT entry. Also repopulates the in-memory hot
  # state that only ever lives in a process (Risk::LiquidationEngine's
  # position cache), so a restart never silently drops an open leveraged
  # position from liquidation monitoring.
  #
  # `available_balance` and `locked_margin` only ever move via
  # Ledger::MarginLedger, which always pairs the mutation with a
  # MARGIN_LOCKED/MARGIN_UNLOCKED entry — so replaying just those two event
  # types against the account's deposited `margin` is sufficient to derive
  # the authoritative wallet split.
  #
  # Safe to run at any time (see config/initializers/reconciler.rb for the
  # boot-time call) — a fully reconciled account produces zero drift and no
  # new ADJUSTMENT entries.
  class Reconciler
    DRIFT_EPSILON = BigDecimal("0.00000001")

    class << self
      def call
        Account.find_each { |account| reconcile_account!(account) }
        Risk::LiquidationEngine.refresh_cache!
      end

      def reconcile_account!(account)
        locked = derived_locked_margin(account.account_id)
        available = derived_available_balance(account, locked)

        locked_drift = (account.locked_margin.to_d - locked).abs
        available_drift = (account.available_balance.to_d - available).abs
        return account if locked_drift <= DRIFT_EPSILON && available_drift <= DRIFT_EPSILON

        cached_available = account.available_balance.to_d
        LedgerEntry.create!(
          account_id: account.account_id,
          event_type: "ADJUSTMENT",
          debit: [cached_available - available, 0].max,
          credit: [available - cached_available, 0].max,
          balance_after: available,
          payload: {
            reason: "reconciliation_drift",
            cached_available_balance: cached_available.to_s,
            derived_available_balance: available.to_s,
            cached_locked_margin: account.locked_margin.to_s,
            derived_locked_margin: locked.to_s
          },
          occurred_at: Time.current
        )

        account.update_columns(available_balance: available, locked_margin: locked)
        account
      end

      private

      def derived_locked_margin(account_id)
        entries = LedgerEntry.where(account_id: account_id)
        locked = entries.where(event_type: "MARGIN_LOCKED").sum(:debit)
        unlocked = entries.where(event_type: "MARGIN_UNLOCKED").sum(:credit)
        locked.to_d - unlocked.to_d
      end

      def derived_available_balance(account, locked)
        entries = LedgerEntry.where(account_id: account.account_id)
        realized = entries.where(event_type: "REALIZED_PNL").sum(:credit).to_d - entries.where(event_type: "REALIZED_PNL").sum(:debit).to_d
        fees = entries.where(event_type: %w[FEE FUNDING_FEE]).sum(:debit).to_d - entries.where(event_type: %w[FEE FUNDING_FEE]).sum(:credit).to_d
        account.margin.to_d - locked + realized - fees
      end
    end
  end
end
