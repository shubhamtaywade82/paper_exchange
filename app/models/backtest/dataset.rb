module Backtest
  # One immutable OHLC series for one instrument and timeframe. Created
  # through Backtest::DatasetManager, which validates the bars first.
  class Dataset < ApplicationRecord
    self.table_name = "backtest_datasets"

    has_many :bars,
      class_name: "Backtest::DatasetBar",
      foreign_key: :backtest_dataset_id,
      inverse_of: :dataset,
      dependent: :delete_all
    has_many :runs,
      class_name: "Backtest::Run",
      foreign_key: :backtest_dataset_id,
      inverse_of: :dataset,
      dependent: :restrict_with_exception

    validates :name, :symbol, :instrument_type, :currency, :timeframe, :fingerprint, presence: true
    validates :timeframe, inclusion: { in: Timeframe::SUPPORTED }
    validates :currency, inclusion: { in: %w[INR USD USDT] }
    validates :bars_count, numericality: { only_integer: true, greater_than_or_equal_to: 2 }
  end
end
