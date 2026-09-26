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

    def reset
      return render_error(:forbidden, "Reset only available in development") unless Rails.env.development? || Rails.env.test?

      reset_margin = requested_margin
      return render_error(:unprocessable_content, "margin must be a finite number greater than 0") unless reset_margin

      # All-or-nothing (audit S11): the wipe spans five tables. A failure
      # midway used to leave the account half-wiped (trades gone, orders
      # still there, wallet untouched). One transaction makes the reset
      # atomic — either the account is fully rebuilt or nothing changed.
      Account.transaction do
        order_ids = ::PaperExchange::PaperOrder.where(account_id: @account_id).pluck(:id)
        FundingPayment.where(account_id: @account_id).delete_all
        ::PaperExchange::PaperTrade.where(paper_order_id: order_ids).delete_all
        ::PaperExchange::PaperPosition.where(account_id: @account_id).delete_all
        ::PaperExchange::PaperOrder.where(account_id: @account_id).delete_all
        LedgerEntry.where(account_id: @account_id).delete_all

        account = Account.find_or_initialize_by(account_id: @account_id)
        account.update!(
          name: "Smoke Test Account", currency: "USD", margin: reset_margin,
          available_balance: reset_margin, current_equity: reset_margin,
          realized_pnl: 0.0, unrealized_pnl: 0.0, locked_margin: 0.0
        )
      end

      render json: { status: "reset_complete", account_id: @account_id, balance: reset_margin }
    end

    private

    # nil means the caller sent an unusable margin; an absent margin falls back to the env default.
    def requested_margin
      raw = params[:margin].presence || (request.raw_post.presence && (JSON.parse(request.raw_post)["margin"] rescue nil))
      return (ENV["PAPER_EXCHANGE_MARGIN"].presence || 10_000.0).to_f if raw.blank?

      margin = Float(raw.to_s)
      margin if margin.finite? && margin.positive? && margin < 1e12
    rescue ArgumentError, TypeError
      nil
    end
  end
end
