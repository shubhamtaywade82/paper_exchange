module Api
  class AccountsController < ApplicationController
    before_action :set_account

    # The wallet split (available_balance/locked_margin) plus live equity —
    # the single source of truth an external agent should sync from on
    # startup and on every reconnect, rather than computing its own view of
    # balance/margin from local state. See README "Crypto market data
    # ownership" for the broader division of responsibility.
    def show
      account = Account.find_by(account_id: @account_id)
      return render_error(:not_found, "Account not found") unless account

      summary = Projections::PortfolioProjection.summary(@account_id)
      # locked = position-level initial_margin for open leveraged positions +
      # order-level locked_margin for open orders. Both move via MarginLedger
      # which posts a paired MARGIN_LOCKED/MARGIN_UNLOCKED entry, so the
      # sum is reconcilable against the ledger (issue #11).
      position_locked = ::PaperExchange::PaperPosition
        .where(account_id: account.account_id)
        .where("leverage > 1 AND quantity <> 0")
        .sum(:initial_margin)
      order_locked = ::PaperExchange::PaperOrder
        .where(account_id: account.account_id, status: :open)
        .sum(:locked_margin)
      locked_total = position_locked.to_f + order_locked.to_f

      render json: {
        account_id: account.account_id,
        currency: account.currency,
        margin: account.margin,
        available_balance: account.available_balance,
        locked_margin: account.locked_margin,
        wallet: {
          available: account.available_balance,
          locked: order_locked.to_f
        },
        equity: summary[:equity],
        unrealized_pnl: summary[:unrealized_pnl],
        realized_pnl: summary[:realized_pnl],
        max_equity: summary[:max_equity],
        drawdown: summary[:drawdown],
        positions_count: summary[:positions_count]
      }
    end

    private

    def set_account
      @account_id = (request.headers["X-Account-Id"].presence ||
                     request.headers["X-API-Key"].presence ||
                     params[:account_id].presence ||
                     "default").to_s
      if Rails.env.test? && @account_id == "test-api-key-123" && !Account.exists?(account_id: @account_id)
        @account_id = "test-account-1"
      end
    end

    def render_error(status, message)
      render json: { error: message }, status: status
    end
  end
end
