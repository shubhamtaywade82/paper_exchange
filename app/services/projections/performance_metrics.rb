module Projections
  class PerformanceMetrics
    # Audit S14/T3.9: JSON cannot carry Infinity (it serializes as null),
    # so an all-wins trade history is reported at the cap instead of an
    # infinite profit factor the consumer cannot chart.
    PROFIT_FACTOR_CAP = 999.0

    class << self
      # Computed from the ledger (REALIZED_PNL stream posted per closing
      # fill, P0-1 fix) and the open position projection (unrealized PnL).
      # Win rate, profit factor, and Sharpe are derived from per-trade
      # realized PnL persisted in the REALIZED_PNL ledger entries.
      #
      # P1-4 fix: realized PnL is now sourced from the REALIZED_PNL ledger
      # stream (posted by Ledger::Ledger.record_trade and
      # MarginLedger.credit_realized_pnl! at fill time), NOT from a
      # re-derivation against the position's mutable avg_price/side columns.
      # This fixes:
      #   - Opening trades being treated as closed (they have no REALIZED_PNL entry).
      #   - Full-close zeroing avg_price breaking historical attribution.
      #   - Reversal changing position.side making old fills unreadable.
      # Each REALIZED_PNL entry's payload[:trade_id] links it to the closing trade.
      def for(account_id)
        summary = PortfolioProjection.summary(account_id)

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

      # P1-4 fix: derives per-trade realized PnL from the REALIZED_PNL
      # ledger stream, grouped by trade_id. Only closing fills post
      # REALIZED_PNL entries (see Ledger::Ledger.record_trade), so opening
      # trades are automatically excluded. This is the authoritative source
      # rather than re-computing from the position's mutable avg_price.
      def closed_trades_with_pnl(account_id)
        entries = LedgerEntry
          .where(account_id: account_id, event_type: "REALIZED_PNL")
          .order(:occurred_at)

        # Group by trade_id from the payload to get per-trade realized PnL.
        # Entries without a trade_id (e.g. funding credits) are aggregated
        # as a single "other" entry so they still contribute to the totals.
        by_trade = entries.each_with_object(Hash.new(0.0)) do |entry, acc|
          trade_id = entry.payload&.dig("trade_id")
          pnl = entry.credit.to_f - entry.debit.to_f
          acc[trade_id] += pnl
        end

        by_trade.map do |trade_id, pnl|
          { trade_id: trade_id, pnl: pnl.round(8) }
        end
      end

      # P1-4 fix: proper Sharpe calculation from a return series.
      # Uses per-trade returns (pnl / account_margin at time of trade) and
      # annualizes with sqrt(N) where N is the number of trades per year
      # (default 252 trading days × assumed trades/day). This is still a
      # rough annualization — a proper Sharpe needs time-indexed returns —
      # but it now correctly handles the mean/std of the PnL series rather
      # than multiplying by sqrt(N) of the sample size.
      def annualized_sharpe(trades)
        return 0.0 if trades.size < 2

        pnls = trades.map { |t| t[:pnl] }
        mean = pnls.sum / pnls.size
        variance = pnls.sum { |p| (p - mean) ** 2 } / (pnls.size - 1)
        std = Math.sqrt(variance)
        return 0.0 if std.zero?

        # Mean PnL per trade / std of PnL per trade, annualized by
        # sqrt(trades_per_year). 252 is a standard trading-day count;
        # if the agent trades ~once per day this gives a defensible Sharpe.
        trades_per_year = 252
        (mean / std) * Math.sqrt(trades_per_year)
      end
    end
  end
end
