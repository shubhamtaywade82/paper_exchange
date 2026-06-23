module Exchange
  class SlippageEngine
    def initialize(equity_impact_factor: 0.0002, option_impact_factor: 0.00005, max_slippage: 0.01)
      @equity_impact_factor = equity_impact_factor
      @option_impact_factor = option_impact_factor
      @max_slippage = max_slippage
    end

    def apply(price:, quantity:, side:, instrument_type: "equity")
      factor = instrument_type == "option" ? @option_impact_factor : @equity_impact_factor
      impact = (quantity * factor).clamp(0, @max_slippage * price)
      side == "buy" ? price + impact : price - impact
    end

    def fill_price(market_snapshot:, side:, instrument_type: "equity")
      raise "Missing bid" if side == "sell" && market_snapshot[:bid].nil?
      raise "Missing ask" if side == "buy" && market_snapshot[:ask].nil?
      base = side == "buy" ? market_snapshot[:ask] : market_snapshot[:bid]
      apply(price: base, quantity: 1, side: side, instrument_type: instrument_type)
    end
  end
end
