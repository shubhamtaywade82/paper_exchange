module Backtest
  # Lifecycle operations on runs and their paper accounts: create, claim, fail,
  # reset, destroy.
  #
  # A run owns exactly the rows that carry its account_id (orders, trades,
  # positions, ledger entries, risk events, funding payments, protections),
  # plus its own intents, equity points and trades. Reset and destroy delete
  # only those. The ledger trigger blocks UPDATE but allows DELETE, which is the
  # documented reset path (see Ledger::Immutability).
  module RunManager
    class Conflict < StandardError; end

    module_function

    # Creates a run and prepares its paper account in one transaction, so the
    # account can be read (GET /api/account) before the first bar.
    def create!(attrs)
      Run.transaction do
        run = Run.create!(attrs)
        clear!(run)
        run
      end
    end

    # Atomically moves a pending engine run to running. Returns false when another
    # worker already claimed it, so a duplicate job is a no-op. External runs are
    # driven over the API and are never claimed.
    def claim!(run)
      run.with_lock do
        next false unless run.status == "pending" && run.mode == "engine"

        run.update!(status: "running", started_at: Time.current, completed_at: nil, failure_reason: nil)
        true
      end
    end

    def fail!(run, error)
      run.update!(
        status: "failed",
        failure_reason: "#{error.class}: #{error.message}".truncate(2000),
        completed_at: Time.current
      )
    end

    # Clears the run's results and paper account, and returns it to pending
    # with its initial balance. The definition is kept. An engine run that is
    # executing cannot be reset; an external run can be reset at any point.
    def reset!(run)
      raise Conflict, "run #{run.id} is executing; it cannot be reset until it finishes" if run.mode == "engine" && run.running?

      Run.transaction do
        clear!(run)
        run.update!(
          status: "pending",
          bars_processed: 0,
          replay_at: nil,
          metrics: {},
          verdict: {},
          diagnostics: {},
          failure_reason: nil,
          started_at: nil,
          completed_at: nil
        )
      end
      run
    end

    def destroy!(run)
      raise Conflict, "run #{run.id} is executing; it cannot be deleted until it finishes" if run.mode == "engine" && run.running?

      Run.transaction do
        purge_account_data!(run.account_id)
        Account.where(account_id: run.account_id).delete_all
        run.destroy!
      end
    end

    # Makes the run pristine: no account rows, no intents, no equity points, no
    # trades, and the balance at the initial capital.
    def clear!(run)
      Account.transaction do
        purge_account_data!(run.account_id)
        run.trades.delete_all
        run.intents.delete_all
        run.equity_points.delete_all
        upsert_account!(run)
      end
    end

    def upsert_account!(run)
      account = Account.find_or_initialize_by(account_id: run.account_id)
      capital = run.initial_capital
      account.update!(
        name: "Backtest #{run.id}",
        simulated: true,
        currency: run.dataset.currency,
        margin: capital,
        available_balance: capital,
        current_equity: capital,
        max_equity_achieved: capital,
        realized_pnl: 0,
        unrealized_pnl: 0,
        locked_margin: 0
      )
      account
    end

    # Deletes children before parents: funding and trades reference positions
    # and orders, and trades reference orders.
    def purge_account_data!(account_id)
      order_ids = ::PaperExchange::PaperOrder.where(account_id: account_id).pluck(:id)
      FundingPayment.where(account_id: account_id).delete_all
      PositionProtection.where(account_id: account_id).delete_all
      ::PaperExchange::PaperTrade.where(paper_order_id: order_ids).delete_all
      ::PaperExchange::PaperPosition.where(account_id: account_id).delete_all
      ::PaperExchange::PaperOrder.where(account_id: account_id).delete_all
      LedgerEntry.where(account_id: account_id).delete_all
      RiskEvent.where(account_id: account_id).delete_all
    end
  end
end
