require 'rails_helper'

RSpec.describe Backtest::MetricsCalculator do
  def d(value)
    BigDecimal(value.to_s)
  end

  let(:t) { ->(i) { Time.utc(2026, 11, 2, 3, 45) + i * 300 } }
  let(:trades) do
    [
      { net_pnl: d(100), gross_pnl: d(105), commission: d(5), bars_held: 3 },
      { net_pnl: d(-40), gross_pnl: d(-35), commission: d(5), bars_held: 2 },
      { net_pnl: d(60), gross_pnl: d(65), commission: d(5), bars_held: 1 }
    ]
  end
  # Equity path: peak 10100, trough 9950 (drawdown 150), finish 10120.
  let(:points) do
    [
      [ t.(0), d(10_000), 0 ],
      [ t.(1), d(10_100), 1 ],
      [ t.(2), d(10_060), 1 ],
      [ t.(3), d(9_950), 0 ],
      [ t.(4), d(10_120), 0 ]
    ]
  end

  def compute(trades: self.trades, points: self.points, initial: d(10_000))
    described_class.compute(
      trades: trades, equity_points: points, initial_capital: initial,
      buy_and_hold_return_pct: d('1.5'), periods_per_year: 18_900
    )
  end

  it 'reports the TradingView-style trade statistics' do
    metrics = compute

    expect(metrics).to include(
      total_trades: 3, winning_trades: 2, losing_trades: 1, breakeven_trades: 0,
      net_profit: 120.0, gross_profit: 160.0, gross_loss: 40.0,
      profit_factor: 4.0, avg_trade: 40.0, avg_win: 80.0, avg_loss: -40.0,
      win_loss_ratio: 2.0, largest_win: 100.0, largest_loss: -40.0,
      total_commission: 15.0, max_consecutive_wins: 1, max_consecutive_losses: 1
    )
    expect(metrics[:percent_profitable]).to eq(66.6667)
  end

  it 'reports drawdown from the equity peak, not from the starting capital' do
    metrics = compute

    expect(metrics[:max_drawdown]).to eq(150.0)
    expect(metrics[:max_drawdown_pct]).to be_within(0.0001).of(1.4851)
    expect(metrics[:max_drawdown_at]).to eq(t.(3).iso8601(6))
  end

  it 'reports equity change, open P&L and exposure' do
    metrics = compute

    expect(metrics[:equity_change]).to eq(120.0)
    expect(metrics[:open_pnl]).to eq(0.0)
    expect(metrics[:exposure_time_pct]).to eq(40.0)
    expect(metrics[:buy_and_hold_return_pct]).to eq(1.5)
  end

  it 'caps the profit factor and flags it when there are no losing trades' do
    winners = [ { net_pnl: d(10), gross_pnl: d(10), commission: d(0), bars_held: 1 } ]
    metrics = compute(trades: winners)

    expect(metrics[:profit_factor]).to eq(999.0)
    expect(metrics[:profit_factor_capped]).to be(true)
    expect(metrics[:win_loss_ratio]).to be_nil
  end

  it 'returns nil for undefined ratios when there are no trades, never zero or Infinity' do
    metrics = compute(trades: [], points: [ [ t.(0), d(10_000), 0 ] ])

    expect(metrics).to include(total_trades: 0, profit_factor: nil, percent_profitable: nil, avg_trade: nil,
      sharpe_ratio: nil, sortino_ratio: nil, avg_bars_in_trade: nil)
    expect(metrics[:net_profit]).to eq(0.0)
  end

  it 'returns a nil Sharpe ratio when the equity never moves (zero deviation)' do
    flat = Array.new(5) { |i| [ t.(i), d(10_000), 0 ] }

    expect(compute(trades: [], points: flat)[:sharpe_ratio]).to be_nil
  end

  it 'computes a finite Sharpe and Sortino ratio for a moving equity curve' do
    metrics = compute

    expect(metrics[:sharpe_ratio]).to be_a(Float)
    expect(metrics[:sortino_ratio]).to be_a(Float)
  end
end
