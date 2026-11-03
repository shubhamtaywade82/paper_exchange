# Each run declares how faithfully it replays the market (MULTI_MARKET_SPEC §5.4).
class AddFidelityToBacktestRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :backtest_runs, :fidelity, :string, null: false, default: "ohlc_bar"
    add_check_constraint :backtest_runs,
      "fidelity IN ('ohlc_bar','trade_tick','l1','l2')",
      name: "backtest_runs_fidelity_valid"
  end
end
