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
        [fill_qty, fill_price]
      else
        [:unfilled, nil]
      end
    rescue => e
      order.rejected!(e.message)
      [:rejected, e.message]
    end

    private

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
        [qty, price]
      when "bounded"
        marketable?(order, book) ? compute_fill(order.dup.tap { |o| o.order_kind = "market" }, book) : [:unfilled, nil]
      when "stop_loss"
        triggered?(order, book) ? compute_fill(order.dup.tap { |o| o.order_kind = "market" }, book) : [:unfilled, nil]
      else
        [:rejected, "unsupported"]
      end
    end

    def marketable?(order, book)
      case order.side
      when "buy"  then book[:ask] && book[:ask] <= order.price
      when "sell" then book[:bid] && book[:bid] >= order.price
      else false end
    end

    def triggered?(order, book)
      case order.side
      when "buy"  then book[:ask] && book[:ask] >= order.trigger_price
      when "sell" then book[:bid] && book[:bid] <= order.trigger_price
      else false end
    end
  end
end
