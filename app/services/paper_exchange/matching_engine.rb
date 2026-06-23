module PaperExchange
  class MatchingEngine
    def initialize(fill_engine:, market_data_feed:, slippage_engine:)
      @fill_engine = fill_engine
      @market_data_feed = market_data_feed
      @slippage_engine = slippage_engine
    end

    def execute(order)
      case order.order_type
      when "market"    then execute_market(order)
      when "limit"     then execute_limit(order)
      when "stop_loss" then execute_stop(order)
      else
        order.rejected!("Unsupported order type: #{order.order_type}")
      end

      order
    rescue => e
      order.rejected!(e.message)
    end

    private

    def execute_market(order)
      book = @market_data_feed.snapshot(order.symbol)
      raise "No market data for #{order.symbol}" unless book

      simulate_latency

      fill_price = if order.side == "buy"
        @slippage_engine.price_for_buy(ask: book[:ask], quantity: order.remaining_quantity)
      else
        @slippage_engine.price_for_sell(bid: book[:bid], quantity: order.remaining_quantity)
      end

      available = available_liquidity(order, book)
      fill_qty = [order.remaining_quantity, available].min

      @fill_engine.fill(order, fill_price: fill_price, quantity: fill_qty)

      if fill_qty < order.remaining_quantity
        order.partially_filled!
      else
        order.update!(filled_at: Time.current)
        order.filled!
      end
    end

    def execute_limit(order)
      book = @market_data_feed.snapshot(order.symbol)
      raise "No market data" unless book

      marketable = if order.side == "buy"
        book[:ask] <= order.price
      else
        book[:bid] >= order.price
      end

      if marketable
        execute_market(order)
      else
        order.open!
      end
    end

    def execute_stop(order)
      book = @market_data_feed.snapshot(order.symbol)
      raise "No market data" unless book

      triggered = if order.side == "buy"
        book[:ask] >= order.trigger_price
      else
        book[:bid] <= order.trigger_price
      end

      if triggered
        order.update!(order_type: :market)
        execute_market(order)
      else
        order.open!
      end
    end

    def simulate_latency
      delay = rand(100..500) / 1000.0
      sleep(delay)
    end

    def available_liquidity(order, book)
      if order.side == "buy"
        book[:asks].sum { |price, qty| price <= order.price ? qty : 0 }
      else
        book[:bids].sum { |price, qty| price >= order.price ? qty : 0 }
      end
    end
  end
end
