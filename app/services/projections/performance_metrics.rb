module Projections
  class PerformanceMetrics
    class << self
      def for(account_id)
        summary = PortfolioProjection.summary(account_id)
        {
          unrealized_pnl: summary[:unrealized_pnl],
          realized_pnl: 0,
          total_pnl: summary[:unrealized_pnl],
          max_drawdown: summary[:drawdown],
          sharpe_ratio: 0.0,
          win_rate: 0.0,
          profit_factor: 0.0
        }
      end
    end
  end
end
