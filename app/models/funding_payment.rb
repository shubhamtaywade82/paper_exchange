class FundingPayment < ApplicationRecord
  self.table_name = "funding_payments"

  belongs_to :paper_position, class_name: "PaperExchange::PaperPosition", optional: true

  validates :account_id, presence: true
  validates :symbol, presence: true
  validates :funding_rate, numericality: true
  validates :position_notional, numericality: { greater_than_or_equal_to: 0 }
  validates :amount, numericality: true
  validates :occurred_at, presence: true
end
