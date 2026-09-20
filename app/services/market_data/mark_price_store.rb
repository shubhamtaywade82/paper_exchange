module MarketData
  # Cross-process "hot state" for the latest Binance mark price per symbol.
  #
  # Backed by Redis so every process (web, Sidekiq/Solid Queue jobs, the
  # market data daemon) sees the same price. A position's `current_price`
  # column in Postgres stays a periodic snapshot — nothing here ever writes
  # to the database on a price tick, and callers that need a live mark price
  # (PnL projections, the liquidation engine) read through this store first.
  class MarkPriceStore
    REDIS_KEY = "paper_exchange:mark_prices"

    class << self
      # Called by the market data daemon on every WebSocket tick. Writes are
      # process-local (Concurrent::Hash) plus a Redis mirror — never AR.
      def set(symbol, price)
        key = normalize(symbol)
        local_cache[key] = price.to_f
        with_redis { |r| r.hset(REDIS_KEY, key, price.to_s) }
        price.to_f
      end

      # Same-process callers (the daemon itself, checking its own tick) hit
      # the in-memory cache; every other process falls through to Redis.
      # A Redis outage degrades to "no live price" rather than raising into
      # callers on the order-matching hot path (Exchange::OrderBook) — they
      # already fall back to a static default when this returns nil.
      def get(symbol)
        key = normalize(symbol)
        local_cache[key] || with_redis { |r| r.hget(REDIS_KEY, key)&.to_f }
      end

      def all
        with_redis { |r| r.hgetall(REDIS_KEY).transform_values(&:to_f) } || {}
      end

      def clear
        with_redis { |r| r.del(REDIS_KEY) }
        local_cache.clear
      end

      private

      def normalize(symbol)
        symbol.to_s.upcase
      end

      def local_cache
        @local_cache ||= Concurrent::Hash.new
      end

      def redis
        @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
      end

      def with_redis
        yield redis
      rescue Redis::BaseError => e
        Rails.logger.warn("[MarkPriceStore] Redis unavailable (#{e.message}) — falling back to no live price") if defined?(Rails)
        nil
      end
    end
  end
end
