module PaperExchange
  class PaperTrade < ApplicationRecord
    self.table_name = "paper_exchange_trades"

    belongs_to :paper_order, class_name: "PaperExchange::PaperOrder"
    belongs_to :paper_position, class_name: "PaperExchange::PaperPosition", optional: true

    validates :side, presence: true
    validates :quantity,
      presence: true,
      numericality: { greater_than: 0 }
    validates :price, presence: true
    validates :price, numericality: { greater_than: 0 }, unless: :option_close?
    # An option that expires out of the money is closed at a premium of
    # exactly 0 (OptionExpiryJob); every other fill must carry a real price.
    validates :price, numericality: { greater_than_or_equal_to: 0 }, if: :option_close?
    validates :traded_at, presence: true

    private

    def option_close?
      side.to_s == "sell" && paper_order&.option_type.present?
    end
  end
end
