module Backtest
  # One simulated run and its results.
  #
  # Two drivers execute a run, and both use the same step-wise replay:
  #
  #   mode "engine"    a built-in strategy decides, and Backtest::Engine drives
  #                    the replay from start to finish (BacktestRunJob)
  #   mode "external"  an external bot decides over the API: POST /advance moves
  #                    the replay one bar, the bot reads the bar, and its orders
  #                    (POST /api/orders on the run's account) execute at the next open
  #
  # Lifecycle: pending -> running -> completed | failed. A completed run keeps
  # its trades, equity, metrics and verdict until it is reset or deleted.
  class Run < ApplicationRecord
    self.table_name = "backtest_runs"

    STATUSES = %w[pending running completed failed].freeze
    MODES = %w[engine external].freeze

    belongs_to :dataset,
      class_name: "Backtest::Dataset",
      foreign_key: :backtest_dataset_id,
      inverse_of: :runs
    has_many :trades,
      class_name: "Backtest::Trade",
      foreign_key: :backtest_run_id,
      inverse_of: :run,
      dependent: :delete_all
    has_many :intents,
      class_name: "Backtest::Intent",
      foreign_key: :backtest_run_id,
      inverse_of: :run,
      dependent: :delete_all
    has_many :equity_points,
      class_name: "Backtest::EquityPoint",
      foreign_key: :backtest_run_id,
      inverse_of: :run,
      dependent: :delete_all

    before_validation :assign_account_id, on: :create

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :mode, inclusion: { in: MODES }
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

    def completed?
      status == "completed"
    end

    def external?
      mode == "external"
    end

    def engine?
      mode == "engine"
    end

    # The replay accepts bar input and orders until it is finished.
    def replayable?
      %w[pending running].include?(status)
    end

    private

    # Each run trades on its own paper account. The prefix keeps it apart
    # from live accounts such as "default".
    def assign_account_id
      self.account_id ||= "backtest-#{SecureRandom.hex(8)}"
    end
  end
end
