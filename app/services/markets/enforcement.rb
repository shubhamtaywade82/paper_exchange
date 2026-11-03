module Markets
  # Whether reference-data enforcement refuses orders: instrument master, lot,
  # tick, freeze quantity, validity windows and the trading calendar.
  #
  # Off by default. Enforcing against an empty instrument master or calendar
  # refuses every Indian order, so it is switched on only once that data is
  # loaded (MULTI_MARKET_SPEC §14). Enable with PAPER_EXCHANGE_MARKET_RULES=enforce.
  #
  # Refusals that need no reference data (instrument types with no rules yet) are
  # always on, and do not consult this switch.
  module Enforcement
    module_function

    def enforce?
      ENV.fetch("PAPER_EXCHANGE_MARKET_RULES", "off") == "enforce"
    end
  end
end
