class MarketStructureSnapshot < ApplicationRecord
  self.table_name = "market_structure_snapshots"

  validates :symbol, presence: true
  validates :timeframe, presence: true
  validates :as_of, presence: true

  # Newest row per symbol for a timeframe. PostgreSQL DISTINCT ON — this
  # app is Postgres-only (partial unique indexes, jsonb, ledger
  # immutability trigger), so the PG-specific set is fine here.
  scope :latest_per_symbol, ->(timeframe:) {
    where(timeframe: timeframe.to_s)
      .order(:symbol, as_of: :desc, id: :desc)
      .select("DISTINCT ON (symbol) *")
  }
end
