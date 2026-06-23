class MarketStructureSnapshot < ApplicationRecord
  self.table_name = "market_structure_snapshots"

  validates :symbol, presence: true
  validates :timeframe, presence: true
  validates :as_of, presence: true
end
