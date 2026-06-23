module Projections
  class PortfolioProjection
    class << self
      def summary(account_id)
        positions = PositionProjection.for_account(account_id)
        unrealized = positions.sum { |p| p[:unrealized_pnl] }
        equity = (ENV.fetch("PAPER_EXCHANGE_MARGIN", "100000").to_f)
        {
          account_id: account_id,
          positions_count: positions.size,
          unrealized_pnl: unrealized,
          equity: equity,
          max_equity: equity,
          drawdown: 0
        }
      end

      def rebuild_for_account(account_id)
        # Placeholder: rebuild caches from ledger
      end
    end
  end
end
