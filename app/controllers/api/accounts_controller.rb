module Api
  class AccountsController < BaseController
    # The wallet split (available_balance/locked_margin) plus live equity —
    # the single source of truth an external agent should sync from on
    # startup and on every reconnect, rather than computing its own view of
    # balance/margin from local state. See README "Crypto market data
    # ownership" for the broader division of responsibility.
    def show
      account = Account.find_by(account_id: @account_id)
      return render_error(:not_found, "Account not found") unless account

      summary = Projections::PortfolioProjection.summary(@account_id)

      render json: {
        account_id: account.account_id,
        currency: account.currency,
        margin: account.margin,
        available_balance: account.available_balance,
        locked_margin: account.locked_margin,
        wallet: {
          available: account.available_balance,
          locked: ::PaperExchange::PaperOrder.where(account_id: account.account_id, status: :open).sum(:locked_margin).to_f
        },
        equity: summary[:equity],
        unrealized_pnl: summary[:unrealized_pnl],
        realized_pnl: summary[:realized_pnl],
        max_equity: summary[:max_equity],
        drawdown: summary[:drawdown],
        positions_count: summary[:positions_count]
      }
    end
  end
end
