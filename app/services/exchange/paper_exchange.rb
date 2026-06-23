module Exchange
  class PaperExchange
    attr_reader :account_id

    def initialize(account_id:)
      @account_id = account_id
      @books = {}
      @mutex = Mutex.new
      @order_book = OrderBook.new(@mutex, @books)
      @slippage = SlippageEngine.new
      @latency = LatencyEngine.new
      @matching = MatchingEngine.new(order_book: @order_book, slippage: @slippage, latency: @latency)
      @fill_engine = FillEngine.new(slippage: @slippage)
      @settlement = SettlementEngine.new(account_id: account_id)
    end

    def submit_order(order_attrs)
      valid, attrs = Exchange::OrderValidator.call(order_attrs)
      raise "Invalid order: #{attrs.inspect}" unless valid

      signal = Strategy::Signal.new(
        account_id: account_id,
        symbol: attrs[:symbol],
        side: attrs[:side],
        quantity: attrs[:quantity],
        order_type: attrs[:order_type],
        instrument_type: attrs[:instrument_type],
        option_type: attrs[:option_type],
        strike_price: attrs[:strike_price],
        expiry_date: attrs[:expiry_date],
        ltp: attrs[:ltp],
        context: attrs.fetch(:context, {})
      )

      passed, _ = Risk::RiskManager.evaluate(account_id: account_id, signal: signal)
      raise "Risk check failed" unless passed

      order = ::PaperExchange::PaperOrder.new(
        order_attrs.merge(account_id: account_id, placed_at: Time.current)
      )
      ::PaperExchange::PaperOrder.transaction do
        order.save!
        order.open!
        result = @matching.execute(order)
        fill_qty, fill_price = result if result.is_a?(Array) && result[0].is_a?(Numeric)

        if fill_qty && fill_qty.positive?
          fill_qty, fill_price, trade = @fill_engine.fill(order, market_snapshot: @order_book.snapshot(order.symbol), instrument_type: order.instrument_type, quantity: fill_qty)
          PositionManager.apply!(account_id: account_id, symbol: order.symbol, side: order.side, quantity: order.side == "buy" ? fill_qty : -fill_qty, avg_price: fill_price) if trade
          Ledger::Ledger.record_trade(account_id: account_id, trade: trade) if trade
          @settlement.settle(order, fill_qty: fill_qty, fill_price: fill_price)
        end

        MarketData::OrderEvent.new(
          order_id: order.id,
          account_id: account_id,
          symbol: order.symbol,
          side: order.side,
          order_type: order.order_type,
          quantity: order.quantity,
          price: order.price,
          trigger_price: order.trigger_price,
          status: order.status,
          timestamp: Time.current
        )
        result
      end
    rescue => e
      order.rejected!(e.message) if order&.persisted?
      raise
    end

    def cancel_order(order_id)
      order = ::PaperExchange::PaperOrder.lock.find_by(id: order_id, account_id: account_id)
      raise "Order not found" unless order
      raise "Cannot cancel" unless order.pending? || order.open?
      order.cancel!
    end

    def market_event(event)
      case event
      when MarketData::MarketEvent
        @order_book.apply_snapshot(
          event.symbol,
          bid: event.bid,
          ask: event.ask,
          ltp: event.ltp,
          depth: event.to_h[:depth],
          timestamp: event.timestamp
        )
      end
    end

    def order_book(symbol)
      @order_book.snapshot(symbol)
    end
  end
end
