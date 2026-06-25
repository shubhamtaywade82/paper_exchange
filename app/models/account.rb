class Account < ApplicationRecord
  self.table_name = "accounts"

  validates :account_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :currency, presence: true, inclusion: { in: %w[INR USD] }
  validates :margin, numericality: { greater_than_or_equal_to: 0 }
  validates :current_equity, numericality: { greater_than_or_equal_to: 0 }
  validates :realized_pnl, numericality: true, allow_nil: true
  validates :unrealized_pnl, numericality: true, allow_nil: true

  after_initialize :set_defaults

  def balance_after
    margin + unrealized_pnl.to_f + realized_pnl.to_f
  end

  private

  def set_defaults
    return unless new_record?

    self.margin = ENV.fetch("PAPER_EXCHANGE_MARGIN", "100000").to_f if margin.nil? || margin.zero?
    self.current_equity = margin if current_equity.nil? || current_equity.zero?
    self.realized_pnl = 0.0 if realized_pnl.nil? || realized_pnl.zero?
    self.unrealized_pnl = 0.0 if unrealized_pnl.nil? || unrealized_pnl.zero?
  end
end
