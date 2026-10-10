module Exchange
  class MatchingEngine
    def initialize(order_book:, slippage:, latency:)
      @order_book = order_book
      @slippage = slippage
      @latency = latency
    end

    def execute(order)
      raise "Unsupported order type" unless ::PaperExchange::PaperOrder.order_kinds.key?(order.order_kind)

      @latency.simulate
      book = @order_book.snapshot(order.symbol)
      raise "No book for #{order.symbol}" unless book

      fill_qty, fill_price = compute_fill(order, book)

      if fill_qty && fill_qty.positive?
        [ fill_qty, fill_price ]
      else
        [ :unfilled, nil ]
      end
    rescue => e
      order.rejected!(e.message)
      [ :rejected, e.message ]
    end

    private

    # P2-1 fix: marketable limit orders now fill at the BEST AVAILABLE book
    # price, not at the limit price. A buy limit of 101 with best ask 100
    # fills at 100 (price improvement), not 101. The limit price is only a
    # cap (buy) or floor (sell) — the actual fill price is the executable
    # book price subject to that constraint.
    #
    # Stop-loss orders: a stop-market fills as a market order once triggered
    # (no fixed price); a stop-limit would rest at the limit, but the current
    # model treats stop_loss as stop-market for execution simplicity.
    def compute_fill(order, book)
      case order.order_kind
      when "market"
        qty = order.remaining_quantity
        price = @slippage.fill_price(
          market_snapshot: book,
          side: order.side,
          instrument_type: order.instrument_type,
          quantity: qty
        )
        [ qty, price ]
      when "bounded"
        return [ :unfilled, nil ] unless marketable?(order, book)

        # Fill at the best available book price, capped by the limit.
        # For a buy: fill at min(book_ask, limit_price). For a sell:
        # fill at max(book_bid, limit_price). This gives the order the
        # price improvement the book offers while respecting the limit.
        qty = order.remaining_quantity
        raw_price = @slippage.fill_price(
          market_snapshot: book,
          side: order.side,
          instrument_type: order.instrument_type,
          quantity: qty
        )
        fill_price = clamp_to_limit(raw_price, order)
        [ qty, fill_price ]
      when "stop_loss"
        # Stop-market: triggers at the trigger price, fills as a market
        # order once triggered (no limit on the fill price).
        return [ :unfilled, nil ] unless triggered?(order, book)

        qty = order.remaining_quantity
        price = @slippage.fill_price(
          market_snapshot: book,
          side: order.side,
          instrument_type: order.instrument_type,
          quantity: qty
        )
        [ qty, price ]
      else
        [ :rejected, "unsupported" ]
      end
    end

    # P2-1: clamp the computed fill price to the order's limit so the
    # fill never exceeds the buyer's max or falls below the seller's min.
    def clamp_to_limit(price, order)
      case order.side
      when "buy"  then [ price.to_f, order.price.to_f ].min
      when "sell" then [ price.to_f, order.price.to_f ].max
      else price
      end
    end

    def marketable?(order, book)
      case order.side
      when "buy"  then book[:ask] && book[:ask] <= order.price
      when "sell" then book[:bid] && book[:bid] >= order.price
      else false
      end
    end

    def triggered?(order, book)
      case order.side
      when "buy"  then book[:ask] && book[:ask] >= order.trigger_price
      when "sell" then book[:bid] && book[:bid] <= order.trigger_price
      else false
      end
    end
  end
end
