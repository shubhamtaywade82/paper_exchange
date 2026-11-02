module Backtest
  # Pure fill-price model for the backtest engine. It answers one question per
  # order and per bar: at what price, if any, does this order fill?
  #
  # OHLC bars do not record the order of intrabar moves, so the rules are
  # explicit and conservative:
  #
  #   * at_open:   an order already through its level at the bar open fills
  #                AT THE OPEN (a gap), never at its level. Market orders
  #                always fill at the open.
  #   * intrabar:  otherwise a limit fills at its limit price, and a stop
  #                fills at its trigger price. Both are reachable only if the
  #                bar's range touches them.
  #   * slippage:  applied adversely to market and stop fills only. A limit
  #                never fills worse than its price.
  #
  # Callers evaluate stop-loss orders before limit orders within one bar
  # (adverse-first), so when both protective exits are reachable, the stop
  # wins.
  module FillCalculator
    module_function

    def at_open(kind:, side:, price:, trigger_price:, open:, slippage_bps:)
      case kind
      when "market"
        adverse(open, side, slippage_bps)
      when "bounded"
        return nil if price.nil?

        through = side == "buy" ? open <= price : open >= price
        through ? open : nil
      when "stop_loss"
        return nil if trigger_price.nil?

        triggered = side == "buy" ? open >= trigger_price : open <= trigger_price
        triggered ? adverse(open, side, slippage_bps) : nil
      else
        raise ArgumentError, "unknown order kind #{kind.inspect}"
      end
    end

    def intrabar(kind:, side:, price:, trigger_price:, high:, low:, slippage_bps:)
      case kind
      when "bounded"
        return nil if price.nil?

        reached = side == "buy" ? low <= price : high >= price
        reached ? price : nil
      when "stop_loss"
        return nil if trigger_price.nil?

        reached = side == "buy" ? high >= trigger_price : low <= trigger_price
        reached ? adverse(trigger_price, side, slippage_bps) : nil
      when "market"
        # A market order never rests: it is filled at the open or not at all.
        nil
      else
        raise ArgumentError, "unknown order kind #{kind.inspect}"
      end
    end

    def adverse(price, side, slippage_bps)
      factor = BigDecimal(slippage_bps.to_s) / 10_000
      side == "buy" ? price * (1 + factor) : price * (1 - factor)
    end
  end
end
