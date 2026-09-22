class FundingPayment < ApplicationRecord
  self.table_name = "funding_payments"

  belongs_to :paper_position, class_name: "PaperExchange::PaperPosition", optional: true

  validates :account_id, presence: true
  validates :symbol, presence: true
  validates :funding_rate, numericality: true
  validates :position_notional, numericality: { greater_than_or_equal_to: 0 }
  validates :amount, numericality: true
  validates :occurred_at, presence: true
  # funding_time is the agent-supplied idempotency key (Binance's funding
  # settlement timestamp). When present, (paper_position_id, funding_time)
  # is unique — see the migration. Absent for legacy callers.
end
