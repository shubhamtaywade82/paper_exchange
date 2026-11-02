module Backtest
  # One simulated run: a strategy, its config, and its stored results.
  #
  # Lifecycle: pending -> running -> completed | failed. Reset returns a
  # finished run to pending and clears its results. The definition (dataset,
  # strategy, config) is kept.
  class Run < ApplicationRecord
    self.table_name = "backtest_runs"

    STATUSES = %w[pending running completed failed].freeze

    belongs_to :dataset,
      class_name: "Backtest::Dataset",
      foreign_key: :backtest_dataset_id,
      inverse_of: :runs
    has_many :trades,
      class_name: "Backtest::Trade",
      foreign_key: :backtest_run_id,
      inverse_of: :run,
      dependent: :delete_all

    before_validation :assign_account_id, on: :create

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :strategy_key, presence: true
    validates :initial_capital, numericality: { greater_than: 0 }
    validates :leverage, numericality: { only_integer: true, in: 1..100 }
    validates :lot_size, numericality: { greater_than: 0 }
    validates :slippage_bps, numericality: { greater_than_or_equal_to: 0, less_than: 1000 }
    validates :account_id, presence: true, uniqueness: true

    def pending?
      status == "pending"
    end

    def running?
      status == "running"
    end

    private

    # Each run trades on its own paper account. The prefix keeps it apart
    # from live accounts such as "default".
    def assign_account_id
      self.account_id ||= "backtest-#{SecureRandom.hex(8)}"
    end
  end
end
