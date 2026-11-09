class MarketStructureSnapshot < ApplicationRecord
  self.table_name = "market_structure_snapshots"

  validates :symbol, presence: true
  validates :timeframe, presence: true
  validates :as_of, presence: true

  API_FIELDS = %i[
    symbol timeframe trend last_bos last_choch bullish_fvg_count bearish_fvg_count
    liquidity_sweep order_block premium_discount as_of
  ].freeze

  def api_attributes
    API_FIELDS.index_with { |field| public_send(field) }
  end

  # Newest row per symbol for a timeframe. PostgreSQL DISTINCT ON — this
  # app is Postgres-only (partial unique indexes, jsonb, ledger
  # immutability trigger), so the PG-specific set is fine here.
  scope :latest_per_symbol, ->(timeframe:) {
    where(timeframe: timeframe.to_s)
      .order(:symbol, as_of: :desc, id: :desc)
      .select("DISTINCT ON (symbol) *")
  }
end
