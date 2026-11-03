# Effective-dated, exchange-scoped rule values such as square-off time or the
# forced-exit cutoff before a physically settled expiry. Values are JSON; the
# database forbids overlapping windows for the same (exchange, product, key).
module Markets
  class MarketRule < ApplicationRecord
    self.table_name = "market_rules"

    PRODUCTS = %w[EQUITY_CASH FUTURES OPTIONS].freeze

    belongs_to :exchange, class_name: "Markets::Exchange"

    validates :product, inclusion: { in: PRODUCTS }
    validates :rule_key, :effective_from, :source_ref, presence: true
    validates :value, exclusion: { in: [ nil ] }
  end
end
