module Backtest
  # One bar of a dataset. Written with insert_all in bulk; the OHLC check
  # constraint in the database backs up the Ruby validation.
  class DatasetBar < ApplicationRecord
    self.table_name = "backtest_bars"

    belongs_to :dataset,
      class_name: "Backtest::Dataset",
      foreign_key: :backtest_dataset_id,
      inverse_of: :bars
  end
end
