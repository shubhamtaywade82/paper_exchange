module Projections
  class PortfolioProjection
    class << self
      ZEROS = {
        account_id: nil,
        positions_count: 0,
        unrealized_pnl: 0.0,
        equity: 0.0,
        max_equity: 0.0,
        drawdown: 0.0,
        realized_pnl: 0.0
      }.freeze

      # Computed live on every call from the current mark price
      # (MarketData::MarkPriceStore) and the ledger — never from the
      # Account's cached `current_equity`/`unrealized_pnl` columns, which are
      # only a periodic snapshot refreshed on fills (see
      # Ledger::Ledger.refresh_cached_equity!) and after reconciliation.
      #
      # P0-1/P1-1 fix: equity is now `available + locked + unrealized`
      # (locked_margin includes the full notional of all open positions).
      # The drawdown is computed against a persisted high-water mark
      # (Account.max_equity_achieved) rather than the initial margin, so a
      # real drawdown from a peak is detected even when equity remains above
      # the starting capital. The HWM is updated here on every read so a
      # growing account tracks its peak correctly.
      def summary(account_id)
        account = Account.find_by(account_id: account_id)
        return ZEROS unless account

        positions = PositionProjection.for_account(account_id)
        unrealized = positions.sum { |p| p[:unrealized_pnl].to_f }
        realized = Ledger::Ledger.compute_realized_pnl(account_id)
        equity = Ledger::Ledger.compute_equity(account, unrealized)

        # P1-1: track the equity high-water mark. Updated lazily on read
        # rather than on every fill so the cached account row doesn't need
        # a write on every price push — only when someone actually asks for
        # the summary. The risk gate (MaxDrawdownValidator) reads this
        # column directly for its decision.
        max_equity = [ equity, account.max_equity_achieved.to_f, account.margin.to_f ].max
        if max_equity > account.max_equity_achieved.to_f
          account.update_column(:max_equity_achieved, max_equity.round(8))
        end

        drawdown = max_equity > 0 ? ((max_equity - equity) / max_equity) * 100 : 0.0

        {
          account_id: account_id,
          positions_count: positions.size,
          unrealized_pnl: unrealized.round(2),
          equity: equity.round(2),
          max_equity: max_equity.round(2),
          drawdown: drawdown.round(2),
          realized_pnl: realized.round(2)
        }
      end
    end
  end
end
