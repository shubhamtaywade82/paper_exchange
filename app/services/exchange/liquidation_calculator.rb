module Exchange
  # Simplified perpetual-futures liquidation model:
  #
  #   LONG:  liquidation_price  = entry * (1 - 1/leverage + mmr)
  #   SHORT: liquidation_price  = entry * (1 + 1/leverage - mmr)
  #
  # `mmr` approximates the exchange's maintenance margin rate for the
  # relevant notional tier. This intentionally omits cross-margin sharing
  # across positions and multi-tier maintenance margin brackets — those
  # require a full margin-tier table per symbol, which Binance does not
  # expose on `exchangeInfo`. Only meaningful for leveraged (leverage > 1)
  # positions; unleveraged (spot-style equity/F&O) positions have no
  # liquidation price.
  class LiquidationCalculator
    def self.default_maintenance_margin_rate
      ENV.fetch("PAPER_EXCHANGE_MAINTENANCE_MARGIN_RATE", "0.004").to_f
    end

    def self.liquidation_price(entry_price:, leverage:, side:, maintenance_margin_rate: default_maintenance_margin_rate)
      return nil if entry_price.nil? || leverage.to_i <= 1

      entry = entry_price.to_f
      lev = leverage.to_f

      case side.to_s
      when "long"
        entry * (1 - (1.0 / lev) + maintenance_margin_rate)
      when "short"
        entry * (1 + (1.0 / lev) - maintenance_margin_rate)
      else
        raise ArgumentError, "unknown side #{side.inspect}"
      end
    end

    def self.initial_margin(notional:, leverage:)
      notional.to_f / [leverage.to_i, 1].max
    end
  end
end
