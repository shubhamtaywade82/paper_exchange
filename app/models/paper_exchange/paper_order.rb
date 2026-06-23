module PaperExchange
  class PaperOrder < ApplicationRecord
    self.table_name = "paper_exchange_orders"

    enum :side, { buy: 0, sell: 1 }
    enum :order_kind, { market: 0, bounded: 1, stop_loss: 2 }
    enum :status, {
      pending: 0,
      open: 1,
      partially_filled: 2,
      filled: 3,
      cancelled: 4,
      rejected: 5
    }, default: :pending

    has_many :paper_trades,
      class_name: "PaperExchange::PaperTrade",
      dependent: :destroy

    validates :symbol, presence: true
    validates :side, presence: true
    validates :order_kind, presence: true
    validates :quantity,
      presence: true,
      numericality: { only_integer: true, greater_than: 0 }
    validates :price,
      numericality: { greater_than: 0 },
      allow_nil: true,
      if: -> { bounded? || stop_loss? }
    validates :trigger_price,
      numericality: { greater_than: 0 },
      allow_nil: true,
      if: -> { stop_loss? }
    validates :filled_quantity,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :instrument_type,
      presence: true,
      inclusion: { in: proc { Exchange::DhanInstrumentCatalog::INSTRUMENT_TYPES } }
    validate :enforce_derivative_only_for_indices

    def enforce_derivative_only_for_indices
      return unless symbol.present? && instrument_type.present?

      if Exchange::DhanInstrumentCatalog.index_underlying?(symbol) && !%w[FUTIDX OPTIDX].include?(instrument_type)
        errors.add(:instrument_type, "Indices must be traded via F&O derivatives only (FUTIDX/OPTIDX). Got: #{instrument_type}")
      end
    end
    validates :option_type, inclusion: { in: %w[CE PE] }, allow_nil: true
    validates :strike_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :expiry_date, presence: true, if: -> { option_type.present? }

    before_validation :set_placed_at, on: :create

    def remaining_quantity
      quantity - (filled_quantity || 0)
    end

    def cancel!
      transaction do
        update!(
          status: :cancelled,
          cancelled_at: Time.current
        )
      end
      self
    end

    def rejected!(reason)
      update_columns(
        status: :rejected,
        rejected_at: Time.current,
        rejection_reason: reason
      )
      self
    end

    private

    def set_placed_at
      self.placed_at ||= Time.current
    end
  end
end
