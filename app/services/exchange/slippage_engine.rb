module Exchange
  class SlippageEngine
    def initialize(equity_impact_factor: 0.0002, option_impact_factor: 0.00005, max_slippage: 0.01)
      @equity_impact_factor = equity_impact_factor
      @option_impact_factor = option_impact_factor
      @max_slippage = max_slippage
    end

    def apply(price:, quantity:, side:, instrument_type: "EQUITY")
      impact_factor = impact_factor_for(instrument_type)
      impact = (quantity * impact_factor).clamp(0, @max_slippage * price)
      side == "buy" ? price + impact : price - impact
    end

    def fill_price(market_snapshot:, side:, instrument_type: "EQUITY", quantity: 1)
      raise "Missing bid" if side == "sell" && market_snapshot[:bid].nil?
      raise "Missing ask" if side == "buy" && market_snapshot[:ask].nil?
      base = side == "buy" ? market_snapshot[:ask] : market_snapshot[:bid]
      apply(price: base, quantity: quantity, side: side, instrument_type: instrument_type)
    end

    private

    def impact_factor_for(instrument_type)
      case instrument_type
      when "OPTIDX", "OPTSTK", "OPTCUR" then @option_impact_factor
      else @equity_impact_factor
      end
    end
  end
end
