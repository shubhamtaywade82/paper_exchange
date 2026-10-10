module MarketData
  module Providers
    # Common contract for all exchange market-data adapters. Concrete
    # adapters (BinanceUSDM, CoindcxFutures) translate their SDK's raw
    # responses into the common internal event schema and expose a uniform
    # interface so the connection supervisor and matching worker never need
    # to know which venue a quote came from.
    #
    # Architecture rule (target architecture §2): PaperExchange's matching
    # and accounting logic must not know whether a quote came from Binance or
    # CoinDCX. Every adapter returns the same normalized event shape and
    # carries its venue identity so orders, positions, fills, and funding
    # records stay isolated by venue.
    class Base
      VENUE = "base"

      # Returns an array of instrument descriptors the adapter can serve.
      # Each descriptor is a Hash with at minimum :symbol and :venue.
      def fetch_instruments
        raise NotImplementedError
      end

      # Fetches a one-shot REST snapshot for a single instrument. Returns a
      # normalized Hash with bid, ask, ltp, mark_price, exchange_timestamp.
      def fetch_snapshot(instrument)
        raise NotImplementedError
      end

      # Connects to the venue's streaming feed for the given instruments.
      # The block receives normalized event Hashes as they arrive. The
      # adapter is responsible for reconnection with exponential backoff;
      # the connection supervisor is the outer layer of recovery.
      def connect(instruments:, &on_event)
        raise NotImplementedError
      end

      # Returns a health Hash: { connected: bool, last_event_at: Time|nil,
      # latency_ms: float|nil, error: string|nil }. The exchange status
      # endpoint aggregates these across all active providers.
      def health
        raise NotImplementedError
      end

      # Disconnects from the venue's streaming feed. Called by the
      # ConnectionSupervisor when stopping or reconnection is needed.
      def disconnect
        # Optional — concrete adapters override if they hold a live socket.
        @connected = false if instance_variable_defined?(:@connected)
      end

      # The venue identifier — used as part of the composite key for quotes,
      # orders, and positions so "BTCUSDT" on Binance is distinct from
      # "BTCUSDT" on CoinDCX.
      def venue
        self.class::VENUE
      end
    end
  end
end
