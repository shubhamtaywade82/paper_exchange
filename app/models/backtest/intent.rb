module Backtest
  # One order request inside a run: the unit a decision turns into.
  #
  #   queued     decided (by a bot over the API, or by a built-in strategy) at
  #              the close of a bar, waiting for the next bar's open
  #   submitted  executed: paper_order_id links the PaperExchange order
  #   rejected   refused by validation or the exchange (rejection_reason)
  #   cancelled  withdrawn by the replay (orphaned exit, end of data, ...)
  #
  # Protective legs (stop, take-profit, liquidation) are intents too, with
  # source "bracket" or "liquidation". Each fill can therefore be traced back
  # to the decision and the reason that produced it.
  class Intent < ApplicationRecord
    self.table_name = "backtest_intents"

    STATUSES = %w[queued submitted rejected cancelled].freeze
    SOURCES = %w[api engine bracket liquidation].freeze
    ACTIONS = %w[buy sell close].freeze

    belongs_to :run,
      class_name: "Backtest::Run",
      foreign_key: :backtest_run_id,
      inverse_of: :intents
    belongs_to :parent_intent,
      class_name: "Backtest::Intent",
      optional: true

    validates :source, inclusion: { in: SOURCES }
    validates :status, inclusion: { in: STATUSES }
    validates :action, inclusion: { in: ACTIONS }
    # A close does not need a side: it closes whatever the position is.
    validates :side, inclusion: { in: %w[buy sell] }, unless: -> { action == "close" }

    scope :queued, -> { where(status: "queued") }
    scope :reduce_only, -> { where(reduce_only: true) }

    def queued?
      status == "queued"
    end
  end
end
