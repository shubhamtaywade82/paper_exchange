class Account < ApplicationRecord
  self.table_name = "accounts"

  validates :account_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :currency, presence: true, inclusion: { in: %w[INR USD USDT] }
  validates :margin, numericality: { greater_than_or_equal_to: 0 }
  validates :current_equity, numericality: { greater_than_or_equal_to: 0 }
  validates :realized_pnl, numericality: true, allow_nil: true
  validates :unrealized_pnl, numericality: true, allow_nil: true
  validates :available_balance, numericality: { greater_than_or_equal_to: 0 }
  validates :locked_margin, numericality: { greater_than_or_equal_to: 0 }

  after_initialize :set_defaults

  # Cached snapshot only — the authoritative balance is the append-only
  # LedgerEntry stream. See Ledger::Reconciler for how this is rebuilt, and
  # Projections::PortfolioProjection for the live (unpersisted) equity figure
  # that also folds in the current mark price via MarketData::MarkPriceStore.
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
    self.available_balance = margin if available_balance.nil? || available_balance.zero?
    self.locked_margin = 0.0 if locked_margin.nil?
  end
end
