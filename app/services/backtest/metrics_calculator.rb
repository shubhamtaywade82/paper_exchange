module Backtest
  # TradingView-style strategy-tester metrics, computed from a run's closed
  # trades and its per-bar equity curve.
  #
  # Money is BigDecimal in and rounded to 8 places out. Ratios (Sharpe,
  # Sortino) are Float because they are statistics, not stored money.
  # An undefined metric is nil, never zero and never Infinity:
  #   * profit_factor is capped at 999 (with profit_factor_capped = true) when
  #     there are no losing trades, because JSON cannot carry Infinity
  #   * a Sharpe or Sortino with zero deviation is nil
  module MetricsCalculator
    PROFIT_FACTOR_CAP = 999.0

    module_function

    # trades:        closed trades (Hash, see TradeJournal + bars_held)
    # equity_points: [[bar_at, BigDecimal equity, in_market (0|1)], ...]
    def compute(trades:, equity_points:, initial_capital:, buy_and_hold_return_pct:, periods_per_year:)
      nets = trades.map { |t| t[:net_pnl] }
      wins = nets.select(&:positive?)
      losses = nets.select(&:negative?)
      gross_profit = wins.sum(zero)
      gross_loss = losses.sum(zero).abs
      net_profit = nets.sum(zero)

      final_equity = equity_points.empty? ? initial_capital : equity_points.last[1]
      equity_change = final_equity - initial_capital
      drawdown = max_drawdown(equity_points, initial_capital)
      returns = equity_returns(equity_points.map { |point| point[1] })
      avg_win = average(wins)
      avg_loss = average(losses)

      {
        initial_capital: f(initial_capital),
        final_equity: f(final_equity),
        equity_change: f(equity_change),
        equity_change_pct: pct(equity_change, initial_capital),
        net_profit: f(net_profit),
        net_profit_pct: pct(net_profit, initial_capital),
        open_pnl: f(equity_change - net_profit),
        gross_profit: f(gross_profit),
        gross_loss: f(gross_loss),
        profit_factor: profit_factor(gross_profit, gross_loss, trades.any?),
        profit_factor_capped: gross_loss.zero? && gross_profit.positive?,
        total_trades: trades.size,
        winning_trades: wins.size,
        losing_trades: losses.size,
        breakeven_trades: nets.count(&:zero?),
        percent_profitable: trades.empty? ? nil : (wins.size.to_f / trades.size * 100).round(4),
        avg_trade: f(average(nets)),
        avg_win: f(avg_win),
        avg_loss: f(avg_loss),
        win_loss_ratio: avg_win && avg_loss&.negative? ? f(avg_win / avg_loss.abs) : nil,
        largest_win: f(wins.max),
        largest_loss: f(losses.min),
        total_commission: f(trades.sum(zero) { |t| t[:commission] }),
        max_drawdown: f(drawdown[:amount]),
        max_drawdown_pct: f(drawdown[:pct]),
        max_drawdown_at: drawdown[:at]&.iso8601(6),
        buy_and_hold_return_pct: f(buy_and_hold_return_pct),
        sharpe_ratio: sharpe(returns, periods_per_year),
        sortino_ratio: sortino(returns, periods_per_year),
        exposure_time_pct: exposure(equity_points),
        avg_bars_in_trade: trades.empty? ? nil : (trades.sum { |t| t[:bars_held] }.to_f / trades.size).round(4),
        max_consecutive_wins: streak(nets, :positive?),
        max_consecutive_losses: streak(nets, :negative?),
        periods_per_year: periods_per_year
      }
    end

    def zero
      BigDecimal("0")
    end

    def f(value)
      value&.to_f&.round(8)
    end

    def pct(part, whole)
      return nil if whole.nil? || whole.zero?

      f(part / whole * 100)
    end

    def average(values)
      return nil if values.empty?

      values.sum(zero) / values.size
    end

    def profit_factor(gross_profit, gross_loss, any_trades)
      return nil unless any_trades
      return nil if gross_profit.zero? && gross_loss.zero?
      return PROFIT_FACTOR_CAP if gross_loss.zero?

      [ (gross_profit / gross_loss).to_f.round(4), PROFIT_FACTOR_CAP ].min
    end

    def max_drawdown(points, initial_capital)
      peak = initial_capital
      worst = { amount: zero, pct: zero, at: nil }
      points.each do |at, equity, _in_market|
        peak = equity if equity > peak
        drawdown = peak - equity
        next unless drawdown > worst[:amount]

        worst = { amount: drawdown, pct: peak.positive? ? drawdown / peak * 100 : zero, at: at }
      end
      worst
    end

    def equity_returns(equities)
      equities.each_cons(2).filter_map do |previous, current|
        next unless previous.positive?

        ((current - previous) / previous).to_f
      end
    end

    def sharpe(returns, periods_per_year)
      return nil if returns.size < 2

      mean = returns.sum / returns.size
      variance = returns.sum { |r| (r - mean)**2 } / (returns.size - 1)
      deviation = Math.sqrt(variance)
      return nil if deviation.zero?

      (mean / deviation * Math.sqrt(periods_per_year)).round(4)
    end

    def sortino(returns, periods_per_year)
      return nil if returns.size < 2

      mean = returns.sum / returns.size
      downside = Math.sqrt(returns.sum { |r| [ r, 0.0 ].min**2 } / returns.size)
      return nil if downside.zero?

      (mean / downside * Math.sqrt(periods_per_year)).round(4)
    end

    def exposure(points)
      return nil if points.empty?

      (points.count { |point| point[2] == 1 }.to_f / points.size * 100).round(4)
    end

    def streak(nets, predicate)
      longest = 0
      current = 0
      nets.each do |net|
        current = net.public_send(predicate) ? current + 1 : 0
        longest = current if current > longest
      end
      longest
    end
  end
end
