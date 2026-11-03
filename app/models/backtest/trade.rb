module Backtest
  # One closed round-trip trade of a run: the position from flat to flat,
  # with its entries and exits netted. Derived from the run's fills by
  # Backtest::TradeJournal and stored when the run completes.
  class Trade < ApplicationRecord
    self.table_name = "backtest_trades"

    belongs_to :run,
      class_name: "Backtest::Run",
      foreign_key: :backtest_run_id,
      inverse_of: :trades

    validates :sequence, :symbol, :instrument_type, :direction, :quantity,
      :entry_at, :entry_price, :exit_at, :exit_price, :gross_pnl, :commission,
      :net_pnl, :return_pct, :exit_reason, presence: true
    validates :direction, inclusion: { in: %w[long short] }
  end
end
