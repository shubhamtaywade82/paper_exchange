module PaperExchange
  class PaperPosition < ApplicationRecord
    self.table_name = "paper_exchange_positions"

    enum :side, { long: 0, short: 1 }

    has_many :paper_trades,
      class_name: "PaperExchange::PaperTrade"

    validates :symbol, presence: true
    validates :side, presence: true
    validates :quantity, numericality: { only_integer: true }
    validates :avg_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :current_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    before_save :compute_pnl

    def compute_pnl
      price = current_price || avg_price || 0
      self.unrealized_pnl = PnLEngine.unrealized_pnl(self, price)
    end
  end
end
