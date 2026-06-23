module PaperExchange
  class PaperTrade < ApplicationRecord
    self.table_name = "paper_exchange_trades"

    belongs_to :paper_order, class_name: "PaperExchange::PaperOrder"
    belongs_to :paper_position, class_name: "PaperExchange::PaperPosition", optional: true

    validates :side, presence: true
    validates :quantity,
      presence: true,
      numericality: { only_integer: true, greater_than: 0 }
    validates :price, presence: true, numericality: { greater_than: 0 }
    validates :traded_at, presence: true
  end
end
