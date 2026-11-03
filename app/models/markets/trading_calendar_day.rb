# One exchange-local trading date for one segment. Open dates carry the session
# window. A date with no row is not known, and is never treated as open.
module Markets
  class TradingCalendarDay < ApplicationRecord
    self.table_name = "trading_calendar_days"

    STATUSES = %w[open closed special].freeze

    belongs_to :exchange, class_name: "Markets::Exchange"

    validates :segment, :trade_date, :status, :source_ref, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :trade_date, uniqueness: { scope: %i[exchange_id segment] }
  end
end
