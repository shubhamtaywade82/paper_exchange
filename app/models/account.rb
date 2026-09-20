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

  # `before_validation`, not `after_initialize`: this callback derives
  # available_balance/current_equity FROM margin, so it must run after every
  # attribute has its final value, not at the moment `.new` is called.
  # FactoryBot (and any other caller that does `Model.new` then assigns
  # attributes one at a time rather than in a single mass-assignment hash)
  # would otherwise see this run with margin still nil, bake that into
  # available_balance, and then never revisit it once margin is actually
  # set — available_balance silently desyncs from margin.
  before_validation :set_defaults, on: :create

  # Cached snapshot only — the authoritative balance is the append-only
  # LedgerEntry stream. See Ledger::Reconciler for how this is rebuilt, and
  # Projections::PortfolioProjection for the live (unpersisted) equity figure
  # that also folds in the current mark price via MarketData::MarkPriceStore.
  def balance_after
    margin + unrealized_pnl.to_f + realized_pnl.to_f
  end

  private

  def set_defaults
    self.margin = ENV.fetch("PAPER_EXCHANGE_MARGIN", "100000").to_f if defaultable?(:margin)
    self.current_equity = margin if defaultable?(:current_equity)
    self.realized_pnl = 0.0 if defaultable?(:realized_pnl)
    self.unrealized_pnl = 0.0 if defaultable?(:unrealized_pnl)
    self.available_balance = margin if defaultable?(:available_balance)
    self.locked_margin = 0.0 if locked_margin.nil?
  end

  # True when `attr` is at its zero default because it was never given a
  # value (nil, or the column's own zero default) — false when it was
  # deliberately set to something invalid like "abcd", so that numericality
  # validation can catch it instead of this quietly laundering it into a
  # valid default. Both cast to the same 0.0, so the only way to tell them
  # apart is the raw, pre-type-cast input.
  def defaultable?(attr)
    return false unless send(attr).to_f.zero?

    raw = read_attribute_before_type_cast(attr)
    return true if raw.nil?

    Float(raw.to_s)
    true
  rescue ArgumentError, TypeError
    false
  end
end
