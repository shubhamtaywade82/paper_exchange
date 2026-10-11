# Architecture alignment (target architecture §4): event-driven matching
# worker. Consumes normalized market events from the Redis tick stream and
# evaluates open (working) orders against the latest quotes. This removes
# the dependency on the trading bot staying alive — when a market order is
# submitted, it fills against the freshest quote from QuoteStore; when a
# limit or stop order is resting, this worker continuously evaluates it
# against incoming ticks and fills it when market conditions make it
# executable.
#
# The worker is designed to be run as a Solid Queue recurring job (every
# few seconds) or as a dedicated long-lived consumer process. It reads
# from the Redis tick stream (MarketData::TickProcessor), processes each
# tick through QuoteStore, then scans open orders for the tick's venue +
# instrument and attempts fills.
#
# Idempotency: each fill is wrapped in a row-locked transaction scoped by
# account_id and order_id. A Redis stream redelivery cannot fill an order
# twice — the order's status check (assert_transition!) makes a double
# fill a loud StateError rather than a silent duplicate.
module Exchange
  class MatchingWorker
    # Processes up to `batch_size` ticks from the Redis stream. Called
    # periodically by the recurring job or the long-lived consumer.
    def self.process_pending(batch_size: 100)
      new.process_pending(batch_size: batch_size)
    end

    def process_pending(batch_size: 100)
      events, _cursor = MarketData::TickProcessor.read_last(count: batch_size)
      events.each { |event| process_tick(event) }
      events.size
    end

    # Processes a single normalized market event. Updates QuoteStore, then
    # finds open orders for the event's symbol and attempts to fill them.
    # This is the core of the autonomous matching loop.
    def process_tick(event)
      return unless event.respond_to?(:symbol) && event.respond_to?(:ltp)

      venue = event.respond_to?(:source) ? derive_venue(event) : "paper"
      quote = build_quote_from_event(venue, event)
      MarketData::QuoteStore.set(quote) if quote

      # Find open orders for this symbol across all venues (the venue on the
      # order determines which feed should drive it; for paper venue orders
      # any tick matches).
      open_orders = ::PaperExchange::PaperOrder
        .where(status: :open)
        .where(symbol: event.symbol.to_s.upcase)

      open_orders.find_each do |order|
        evaluate_order(order, quote)
      end
    rescue StandardError => e
      Rails.logger.error("[MatchingWorker] error processing tick for #{event&.symbol}: #{e.class}: #{e.message}")
    end

    private

    # Determines which venue a tick came from. The MarketEvent's source field
    # carries this — "binance_usdm", "coindcx_futures", or "api"/"feed" for
    # agent-pushed ticks (which default to "paper" venue).
    def derive_venue(event)
      source = event.source.to_s
      return source if %w[binance_usdm coindcx_futures].include?(source)
      "paper"
    end

    def build_quote_from_event(venue, event)
      {
        venue: venue,
        instrument_id: event.symbol.to_s.upcase,
        bid: event.bid,
        ask: event.ask,
        bid_quantity: nil,
        ask_quantity: nil,
        ltp: event.ltp || event.price,
        mark_price: event.ltp || event.price,
        exchange_timestamp: event.timestamp,
        received_at: Time.current
      }
    end

    # Evaluates one open order against the current quote. If the order is
    # marketable (market order, or a limit/stop whose condition is met),
    # attempts to fill it through the exchange. The fill is wrapped in a
    # row-locked transaction scoped by the order's account_id.
    def evaluate_order(order, quote)
      return if quote.nil? || quote[:ltp].nil?

      fill_price = compute_fill_price(order, quote)
      return if fill_price.nil?

      # Lock the order row to prevent a concurrent cancel/fill from racing.
      ::PaperExchange::PaperOrder.transaction do
        locked_order = ::PaperExchange::PaperOrder.lock.find(order.id)
        # Re-check status under the lock — a concurrent cancel may have
        # moved it to a terminal state between the scan and the lock.
        return unless locked_order.status == "open"

        exchange = Exchange::PaperExchange.new(account_id: locked_order.account_id)
        exchange.match_and_fill(locked_order, fill_price)
      end
    rescue Exchange::PaperExchange::PositionGoneError, ::PaperExchange::PaperOrder::StateError
      # A raced close or a concurrent fill — the order is no longer fillable.
      nil
    rescue StandardError => e
      Rails.logger.error("[MatchingWorker] error evaluating order #{order.id}: #{e.class}: #{e.message}")
    end

    # Computes the fill price for an order given the current quote. Returns
    # nil if the order is not marketable at the current quote.
    def compute_fill_price(order, quote)
      case order.order_kind.to_s
      when "market"
        # Market orders fill at the best available executable price.
        order.side == "buy" ? quote[:ask] || quote[:ltp] : quote[:bid] || quote[:ltp]
      when "bounded"
        # Limit orders fill only when the book crosses the limit.
        if order.side == "buy"
          return nil unless quote[:ask] && quote[:ask] <= order.price.to_f
          [ quote[:ask].to_f, order.price.to_f ].min # price improvement
        else
          return nil unless quote[:bid] && quote[:bid] >= order.price.to_f
          [ quote[:bid].to_f, order.price.to_f ].max
        end
      when "stop_loss"
        # Stop-market: triggers when the trigger price is breached, then
        # fills at the available executable price.
        if order.side == "buy"
          return nil unless quote[:ask] && quote[:ask] >= order.trigger_price.to_f
          quote[:ask] || quote[:ltp]
        else
          return nil unless quote[:bid] && quote[:bid] <= order.trigger_price.to_f
          quote[:bid] || quote[:ltp]
        end
      else
        nil
      end
    end
  end
end
