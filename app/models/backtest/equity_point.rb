module Backtest
  # Mark-to-market equity of a run's account at one processed bar.
  class EquityPoint < ApplicationRecord
    self.table_name = "backtest_equity_points"

    belongs_to :run,
      class_name: "Backtest::Run",
      foreign_key: :backtest_run_id,
      inverse_of: :equity_points

    validates :bar_at, :equity, presence: true
  end
end
