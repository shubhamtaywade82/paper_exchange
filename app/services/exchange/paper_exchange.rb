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
        order_kind: attrs[:order_kind],
        instrument_type: attrs[:instrument_type],
        option_type: attrs[:option_type],
        strike_price: attrs[:strike_price],
        expiry_date: attrs[:expiry_date],
        ltp: attrs[:ltp],
        context: attrs.fetch(:context, {})
      )

      order = ::PaperExchange::PaperOrder.new(
        order_attrs.merge(account_id: account_id, placed_at: Time.current)
      )
      order.save!
      order.open!

      reference_price = (order.price || attrs[:ltp]).to_f
      required_margin = order.required_margin(reference_price)
      Ledger::MarginLedger.lock_margin!(
        account_id: account_id,
        amount: required_margin,
        reference_id: order.id.to_s,
        payload: { order_id: order.id, symbol: order.symbol, reason: "order_margin_lock" }
      )
      order.update_column(:locked_margin, required_margin)

      result = Risk::RiskManager.evaluate(account_id: account_id, signal: signal)
      _passed, rejected = result
      if Array(rejected).any? { |sym| sym.to_s.end_with?("_REJECTED") }
        release_order_margin!(order)
        order.rejected!("Risk check failed: #{Array(rejected).join(", ")}")
        raise "Risk check failed: #{Array(rejected).join(", ")}"
      end

      ::PaperExchange::PaperOrder.transaction do
        result = @matching.execute(order)
        fill_qty, fill_price = result if result.is_a?(Array) && result[0].is_a?(Numeric)

        if fill_qty && fill_qty.positive?
          fill_qty, fill_price, trade = @fill_engine.fill(order, market_snapshot: @order_book.snapshot(order.symbol), instrument_type: order.instrument_type, quantity: fill_qty)
          if trade
            position = PositionManager.apply!(
              account_id: account_id,
              symbol: order.symbol,
              side: order.side,
              quantity: order.side == "buy" ? fill_qty : -fill_qty,
              avg_price: fill_price,
              leverage: order.leverage,
              margin_type: order.margin_type,
              instrument_type: order.instrument_type
            )
            release_order_margin!(order)
            MarginEngine.sync_position!(position, account_id: account_id)
            Ledger::Ledger.record_trade(account_id: account_id, trade: trade)
          end
          @settlement.settle(order, fill_qty: fill_qty, fill_price: fill_price)
          order.filled!
        end
      end

      MarketData::OrderEvent.new(
        order_id: order.id,
        account_id: account_id,
        symbol: order.symbol,
        side: order.side,
        order_type: order.order_kind,
        quantity: order.quantity,
        price: order.price,
        trigger_price: order.trigger_price,
        status: order.status,
        timestamp: Time.current
      )

      order
    rescue ArgumentError
      raise
    rescue => e
      order.rejected!(e.message) if order&.persisted?
      raise
    end

    def cancel_order(order_id)
      order = ::PaperExchange::PaperOrder.find(order_id)
      release_order_margin!(order)
      order.cancel!
    end

    def expire_order(order_id)
      order = ::PaperExchange::PaperOrder.find(order_id)
      release_order_margin!(order)
      order.expired!
    end

    def market_event(event)
      if event.respond_to?(:symbol) && event.respond_to?(:bid) && event.respond_to?(:ask)
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

    private

    # Releases whatever margin is still held against this order back to the
    # account's available balance. Called once the order's own lock has
    # either been superseded by a position-level lock (fill — see
    # MarginEngine.sync_position!) or is no longer needed (reject, cancel,
    # expiry).
    def release_order_margin!(order)
      return if order.locked_margin.to_f.zero?

      Ledger::MarginLedger.unlock_margin!(
        account_id: order.account_id,
        amount: order.locked_margin,
        reference_id: order.id.to_s,
        payload: { order_id: order.id, symbol: order.symbol, reason: "order_margin_release" }
      )
      order.update_column(:locked_margin, 0)
    end
  end
end
