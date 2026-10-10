module MarketData
  # Cross-process "hot state" for the latest Binance mark price per symbol.
  #
  # Backed by Redis so every process (web, Sidekiq/Solid Queue jobs, the
  # market data daemon) sees the same price. A position's `current_price`
  # column in Postgres stays a periodic snapshot — nothing here ever writes
  # to the database on a price tick, and callers that need a live mark price
  # (PnL projections, the liquidation engine) read through this store first.
  #
  # P2-3 fix: the local in-process cache now has a TTL (default 2 seconds)
  # so a stale price from a different process's write is refreshed from
  # Redis. Previously the cache never expired, so a web process that wrote a
  # price at T=0 would serve that same price indefinitely even after another
  # process wrote a newer value at T=1. This matters for liquidation checks
  # where a stale price can mean a breached position is not detected.
  class MarkPriceStore
    REDIS_KEY = "paper_exchange:mark_prices"
    # P2-3: local cache TTL. Short enough that cross-process writes are
    # visible quickly; long enough that a single mark-price push (which
    # writes both the local cache and Redis) doesn't immediately re-fetch.
    LOCAL_CACHE_TTL = ENV.fetch("PAPER_EXCHANGE_MARK_PRICE_CACHE_TTL", "2").to_f

    class << self
      # Called by the market data daemon on every WebSocket tick. Writes are
      # process-local (Concurrent::Hash with TTL) plus a Redis mirror — never AR.
      def set(symbol, price)
        key = normalize(symbol)
        local_cache[key] = [ price.to_f, Time.now.to_f ]
        with_redis { |r| r.hset(REDIS_KEY, key, price.to_s) }
        price.to_f
      end

      # Same-process callers (the daemon itself, checking its own tick) hit
      # the in-memory cache; every other process falls through to Redis.
      # P2-3: the local cache entry has a TTL — if it's older than
      # LOCAL_CACHE_TTL seconds, we re-fetch from Redis so cross-process
      # writes are visible. A Redis outage degrades to "no live price"
      # rather than raising into callers on the order-matching hot path.
      def get(symbol)
        key = normalize(symbol)
        cached = local_cache[key]
        if cached && (Time.now.to_f - cached[1]) < LOCAL_CACHE_TTL
          return cached[0]
        end

        # Cache miss or expired — fetch from Redis and update the local cache.
        redis_val = with_redis { |r| r.hget(REDIS_KEY, key) }
        return nil unless redis_val

        val = redis_val.to_f
        local_cache[key] = [ val, Time.now.to_f ]
        val
      end

      def all
        with_redis { |r| r.hgetall(REDIS_KEY).transform_values(&:to_f) } || {}
      end

      # Prod-hardening (NEW-38, additive): batch-fetch mark prices for a set
      # of symbols in ONE Redis round-trip (HMGET) instead of N sequential
      # HGETs. Used by read paths that project many positions at once.
      def bulk_get(symbols)
        keys = Array(symbols).map { |s| normalize(s) }
        return {} if keys.empty?

        raw = with_redis { |r| r.hmget(REDIS_KEY, keys) }
        return {} if raw.nil? # Redis unavailable

        keys.zip(raw).each_with_object({}) do |(key, val), acc|
          acc[key] = val.to_f if val
        end
      end

      def redis_healthy?
        with_redis { |r| r.ping } == "PONG"
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
