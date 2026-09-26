module Projections
  class PerformanceMetrics
    # Audit S14/T3.9: JSON cannot carry Infinity (it serializes as null),
    # so an all-wins trade history is reported at the cap instead of an
    # infinite profit factor the consumer cannot chart.
    PROFIT_FACTOR_CAP = 999.0

    class << self
      # Computed from the ledger (closed trades → realized PnL) and the open
      # position projection (unrealized PnL). Win rate, profit factor, and
      # Sharpe are derived from per-trade realized PnL; Sharpe uses the
      # standard sqrt(N) annualization for an N-trade sample (rough — real
      # Sharpe needs a proper return series with timestamps, but this is
      # enough to surface "is the agent profitable" without waiting for a
      # full time-series implementation).
      def for(account_id)
        summary = PortfolioProjection.summary(account_id) # once, not three times

        trades = closed_trades_with_pnl(account_id)
        realized_pnl = trades.sum { |t| t[:pnl] }
        total_pnl = realized_pnl + summary[:unrealized_pnl].to_f
        wins = trades.select { |t| t[:pnl] > 0 }
        losses = trades.select { |t| t[:pnl] < 0 }
        gross_profit = wins.sum { |t| t[:pnl] }
        gross_loss = losses.sum { |t| t[:pnl].abs }.to_f
        win_rate = trades.empty? ? 0.0 : (wins.size.to_f / trades.size)
        profit_factor = if gross_loss.zero?
          gross_profit.positive? ? PROFIT_FACTOR_CAP : 0.0
        else
          [ (gross_profit / gross_loss), PROFIT_FACTOR_CAP ].min
        end
        sharpe = annualized_sharpe(trades)

        {
          unrealized_pnl: summary[:unrealized_pnl],
          realized_pnl: realized_pnl.round(8),
          total_pnl: total_pnl.round(8),
          max_drawdown: summary[:drawdown],
          sharpe_ratio: sharpe,
          win_rate: win_rate.round(4),
          profit_factor: profit_factor.round(4)
        }
      end

      private

      # Per-trade realized PnL — long closes at price > entry, short closes at
      # price < entry. We compute from trades joined to their position's
      # avg_price at the time of the close. This is a rough cut: it doesn't
      # handle partial closes that changed the avg_price mid-position. For
      # those, the authoritative realized PnL is the Ledger::REALIZED_PNL
      # stream, summed by trade_id.
      def closed_trades_with_pnl(account_id)
        trades = ::PaperExchange::PaperTrade
          .joins(:paper_order)
          .where(paper_exchange_orders: { account_id: account_id })
          .order(:traded_at)

        trades.map do |trade|
          pnl = trade_pnl(trade)
          { trade_id: trade.id, pnl: pnl }
        end
      end

      def trade_pnl(trade)
        position = trade.paper_position
        return 0.0 unless position

        entry = position.avg_price.to_f
        exit_price = trade.price.to_f
        qty = trade.quantity.to_f
        side = position.long? ? 1 : -1
        (exit_price - entry) * qty * side - trade.total_charges.to_f
      end

      # Annualized Sharpe from a per-trade PnL series. Returns 0.0 if fewer
      # than 2 trades (variance undefined). ponytail: rough — real Sharpe
      # needs time-indexed returns.
      def annualized_sharpe(trades)
        return 0.0 if trades.size < 2

        pnls = trades.map { |t| t[:pnl] }
        mean = pnls.sum / pnls.size
        variance = pnls.sum { |p| (p - mean) ** 2 } / (pnls.size - 1)
        std = Math.sqrt(variance)
        return 0.0 if std.zero?

        # Assume ~252 trades/year (one trading day) — rough annualization.
        (mean / std) * Math.sqrt(pnls.size)
      end
    end
  end
end
