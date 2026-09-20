module PaperExchange
  class PaperPosition < ApplicationRecord
    self.table_name = "paper_exchange_positions"

    enum :side, { long: 0, short: 1 }

    has_many :paper_trades,
      class_name: "PaperExchange::PaperTrade"
    has_many :funding_payments,
      class_name: "FundingPayment"

    validates :symbol, presence: true
    validates :side, presence: true
    validates :quantity, numericality: true
    validates :avg_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :current_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :leverage, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :margin_type, inclusion: { in: %w[cross isolated] }
    validates :liquidation_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :initial_margin, numericality: { greater_than_or_equal_to: 0 }

    # `avg_price`/`current_price` already carry entry-price and mark-price
    # semantics respectively for both equity and futures positions — these
    # are read-only aliases so futures call sites can use the vocabulary
    # they expect without duplicating (and risking desync of) a column.
    alias_method :entry_price, :avg_price
    alias_method :mark_price, :current_price

    def leveraged?
      leverage.to_i > 1
    end

    def notional_value(price = mark_price)
      price.to_f.abs * quantity.to_f.abs
    end

    def liquidated?(price)
      return false unless leveraged? && liquidation_price.present? && quantity.to_f != 0

      long? ? price.to_f <= liquidation_price.to_f : price.to_f >= liquidation_price.to_f
    end
  end
end
