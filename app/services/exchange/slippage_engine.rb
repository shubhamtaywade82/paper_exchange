module Exchange
  # Top-of-book execution model for the live matching path.
  #
  # The impact is a fraction of price, so a 2 bp impact is 2 bp on a 0.50
  # instrument and on a 100,000 instrument alike. The earlier model added
  # quantity * factor as an absolute currency amount, which made the impact
  # depend on the instrument's price level.
  #
  # Size does not move the price here: the live path does not walk depth, so
  # no size-dependent impact can be derived from data. Size effects belong to
  # the depth-walking replay (Backtest::Tick), not to this model.
  class SlippageEngine
    # Fractions of price: 0.0002 is 2 bp, 0.0005 is 5 bp.
    def initialize(equity_impact_fraction: 0.0002, option_impact_fraction: 0.0005, max_fraction: 0.01)
      @equity_impact_fraction = equity_impact_fraction
      @option_impact_fraction = option_impact_fraction
      @max_fraction = max_fraction
    end

    # A zero price is valid: an option that expires out of the money settles at
    # zero, and a fraction of zero is zero impact. A negative price is not.
    def apply(price:, side:, instrument_type: "EQUITY")
      raise ArgumentError, "price must not be negative" if price.to_f.negative?

      fraction = [ impact_fraction_for(instrument_type), @max_fraction ].min
      impact = price * fraction
      side == "buy" ? price + impact : price - impact
    end

    def fill_price(market_snapshot:, side:, instrument_type: "EQUITY")
      raise "Missing bid" if side == "sell" && market_snapshot[:bid].nil?
      raise "Missing ask" if side == "buy" && market_snapshot[:ask].nil?

      base = side == "buy" ? market_snapshot[:ask] : market_snapshot[:bid]
      apply(price: base, side: side, instrument_type: instrument_type)
    end

    private

    def impact_fraction_for(instrument_type)
      case instrument_type
      when "OPTIDX", "OPTSTK", "OPTFUT", "OPTCUR", "CRYPTO_OPTION" then @option_impact_fraction
      else @equity_impact_fraction
      end
    end
  end
end
