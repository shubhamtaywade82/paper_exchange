module MarketData
  # Architecture alignment (target architecture §3 + §7): the connection
  # supervisor runs as a long-lived process independently of Puma and the
  # trading bot. Its responsibilities:
  #
  #   1. Load active instruments from PaperExchange's persisted open orders,
  #      positions, and protection policies.
  #   2. Fetch initial REST snapshots to bootstrap prices, book state, and
  #      instrument metadata.
  #   3. Subscribe to the appropriate public WebSocket channels via the
  #      provider adapters.
  #   4. Normalize incoming ticks and publish them into the Redis tick
  #      stream (MarketData::TickProcessor) and QuoteStore.
  #   5. Reconnect on dropped connections, refresh snapshots after gaps,
  #      and expose connection health.
  #   6. Rebuild subscriptions from durable state after a process restart.
  #
  # In production this runs as a dedicated process (e.g. `bin/jobs` for the
  # market_data queue, or a standalone `bin/market_data` supervisor). Only
  # ONE active WebSocket subscription owner should be responsible for a
  # given provider/shard unless a redundant active-active arrangement is
  # explicitly designed — use a distributed lease to prevent duplicate
  # publishers.
  #
  # This is the skeleton — the actual SDK-specific connection lifecycle is
  # delegated to the provider adapters (BinanceUSDM, CoinDCXFutures).
  class ConnectionSupervisor
    def initialize(providers: [])
      @providers = providers
      @running = false
    end

    # Starts the supervisor loop. Subscribes to all active instruments,
    # then enters a reconnect/watch loop that runs until #stop is called.
    def start
      @running = true
      instruments = load_active_instruments

      @providers.each do |provider|
        bootstrap(provider, instruments)
      end

      # In a real deployment this would be a blocking event loop; for
      # Solid Queue integration it's invoked as a recurring job.
      watch_loop if @running
    end

    def stop
      @running = false
      @providers.each(&:disconnect) rescue nil
    end

    # Fetches a REST snapshot for every instrument and writes it to
    # QuoteStore. Called on startup and after a reconnection gap to
    # ensure the store is not stale.
    def bootstrap(provider, instruments)
      instruments.each do |inst|
        snapshot = provider.fetch_snapshot(inst)
        next unless snapshot

        MarketData::QuoteStore.set(snapshot)
        MarketData::TickProcessor.enqueue(
          MarketEvent.new(
            symbol: snapshot[:instrument_id],
            bid: snapshot[:bid],
            ask: snapshot[:ask],
            ltp: snapshot[:ltp],
            timestamp: snapshot[:exchange_timestamp],
            source: provider.venue
          )
        )
      end
    rescue StandardError => e
      Rails.logger.error("[ConnectionSupervisor] bootstrap failed for #{provider.venue}: #{e.class}: #{e.message}")
    end

    # Connects the provider's WebSocket stream and routes normalized
    # events into QuoteStore + the tick stream.
    def subscribe(provider, instruments)
      provider.connect(instruments: instruments) do |event|
        handle_event(event)
      end
    rescue StandardError => e
      Rails.logger.error("[ConnectionSupervisor] subscribe failed for #{provider.venue}: #{e.class}: #{e.message}")
    end

    private

    # Loads the set of instruments that need live market data — every
    # symbol with an open order, open position, or active protection.
    def load_active_instruments
      symbols = Set.new
      ::PaperExchange::PaperOrder.where(status: :open).distinct.pluck(:venue, :symbol).each do |venue, sym|
        symbols << { venue: venue, symbol: sym }
      end
      ::PaperExchange::PaperPosition.where("quantity <> 0").distinct.pluck(:venue, :symbol).each do |venue, sym|
        symbols << { venue: venue, symbol: sym }
      end
      ::PositionProtection.where(status: "active").distinct.pluck(:venue, :instrument_id).each do |venue, sym|
        symbols << { venue: venue, symbol: sym }
      end
      symbols.to_a
    end

    # Handles one normalized event from a provider. Writes it to QuoteStore
    # and enqueues it into the tick stream so the MatchingWorker and other
    # consumers see it.
    def handle_event(event)
      MarketData::QuoteStore.set(event) if event[:instrument_id]

      MarketData::TickProcessor.enqueue(
        MarketEvent.new(
          symbol: event[:instrument_id],
          bid: event[:bid],
          ask: event[:ask],
          ltp: event[:ltp] || event[:mark_price] || event[:price],
          timestamp: event[:exchange_timestamp] || Time.current,
          source: event[:venue]
        )
      )
    rescue StandardError => e
      Rails.logger.error("[ConnectionSupervisor] error handling event: #{e.class}: #{e.message}")
    end

    # The watch loop periodically checks provider health and reconnects
    # dropped connections. In production this would be a blocking event
    # loop; here it's a poll-based loop suitable for a recurring job.
    def watch_loop
      while @running
        @providers.each do |provider|
          health = provider.health
          next if health[:connected]

          Rails.logger.warn("[ConnectionSupervisor] #{provider.venue} disconnected (#{health[:error]}), reconnecting...")
          subscribe(provider, load_active_instruments)
        end
        sleep 5
      end
    end
  end
end
