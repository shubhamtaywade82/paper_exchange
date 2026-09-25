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
      def summary(account_id)
        account = Account.find_by(account_id: account_id)
        return ZEROS unless account

        positions = PositionProjection.for_account(account_id)
        unrealized = positions.sum { |p| p[:unrealized_pnl].to_f }
        realized = Ledger::Ledger.compute_realized_pnl(account_id)
        equity = Ledger::Ledger.compute_equity(account, unrealized)
        max_equity = [ equity, account.margin.to_f ].max
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
