module Exchange
  class MatchingEngine
    def initialize(order_book:, slippage:, latency:)
      @order_book = order_book
      @slippage = slippage
      @latency = latency
    end

    def execute(order)
      raise "Unsupported order type" unless ::PaperExchange::PaperOrder.order_types.key?(order.order_type)

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
      case order.order_type
      when "market"
        qty = order.remaining_quantity
        price = if order.side == "buy"
          @slippage.price_for_buy(ask: book[:ask], quantity: qty)
        else
          @slippage.price_for_sell(bid: book[:bid], quantity: qty)
        end
        [qty, price]
      when "limit"
        marketable?(order, book) ? compute_fill(order.dup.tap { |o| o.order_type = "market" }, book) : [:unfilled, nil]
      when "stop_loss"
        triggered?(order, book) ? compute_fill(order.dup.tap { |o| o.order_type = "market" }, book) : [:unfilled, nil]
      else
        [:rejected, "unsupported"]
      end
    end

    def marketable?(order, book)
      case order.side
      when "buy"  then book[:ask] <= order.price
      when "sell" then book[:bid] >= order.price
      else false end
    end

    def triggered?(order, book)
      case order.side
      when "buy"  then book[:ask] >= order.trigger_price
      when "sell" then book[:bid] <= order.trigger_price
      else false end
    end
  end
end
