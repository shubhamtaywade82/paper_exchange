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
      rejected: 5,
      expired: 6
    }, default: :pending

    has_many :paper_trades,
      class_name: "PaperExchange::PaperTrade",
      dependent: :destroy

    validates :symbol, presence: true
    validates :side, presence: true
    validates :order_kind, presence: true
    validates :quantity,
      presence: true,
      numericality: { greater_than: 0 }
    validates :price,
      numericality: { greater_than: 0 },
      allow_nil: true,
      if: -> { bounded? || stop_loss? }
    validates :trigger_price,
      numericality: { greater_than: 0 },
      allow_nil: true,
      if: -> { stop_loss? }
    validates :filled_quantity,
      numericality: { greater_than_or_equal_to: 0 }
    validates :leverage, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :margin_type, inclusion: { in: %w[cross isolated] }
    validates :client_order_id, uniqueness: { scope: :account_id }, allow_nil: true
    validates :instrument_type,
      presence: true,
      inclusion: { in: proc { Exchange::DhanInstrumentCatalog::INSTRUMENT_TYPES + Exchange::CryptoInstrumentCatalog::INSTRUMENT_TYPES } }
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

    # Raised when a state transition is attempted from a status it is not
    # legal from (audit S1/N1) — e.g. cancelling an already-filled order or
    # expiring a rejected one. `rejected!` deliberately stays unguarded: it
    # is the terminal safety net in submit_order's rescue path and must
    # never raise.
    class StateError < StandardError; end

    def remaining_quantity
      quantity - (filled_quantity || 0)
    end

    # Notional value at a given reference price (defaults to the order's own
    # limit/trigger price where set — callers filling at market must pass the
    # fill price explicitly since `price` is nil for market orders).
    def notional(reference_price)
      reference_price.to_f * quantity.to_f
    end

    # Initial margin required to open this order's full quantity at the given
    # reference price under the order's own leverage.
    def required_margin(reference_price)
      notional(reference_price) / leverage.to_f
    end

    # Legal transitions (audit S1/N1):
    #   pending        → open, cancelled, rejected, expired
    #   open           → filled, partially_filled, cancelled, rejected, expired
    #   partially_filled → filled, partially_filled, cancelled, open, rejected, expired
    #   filled/cancelled/rejected/expired are terminal
    def cancel!
      assert_transition!(%w[pending open partially_filled], :cancel)
      transaction do
        update!(
          status: :cancelled,
          cancelled_at: Time.current
        )
      end
      self
    end

    def open!
      assert_transition!(%w[pending partially_filled], :open)
      update!(status: :open)
      self
    end

    def filled!
      assert_transition!(%w[open partially_filled], :fill)
      update!(
        status: :filled,
        filled_at: Time.current,
        filled_quantity: quantity
      )
      self
    end

    def partially_filled!(fill_qty)
      assert_transition!(%w[open partially_filled], :partially_fill)
      update!(
        status: :partially_filled,
        filled_quantity: (filled_quantity || 0) + fill_qty
      )
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

    def expired!
      assert_transition!(%w[pending open partially_filled], :expire)
      update!(
        status: :expired,
        expired_at: Time.current
      )
      self
    end

    private

    def assert_transition!(allowed_statuses, action)
      return if allowed_statuses.include?(status)

      raise StateError, "cannot #{action} a #{status} order (legal from: #{allowed_statuses.join(', ')})"
    end

    def set_placed_at
      self.placed_at ||= Time.current
    end
  end
end
