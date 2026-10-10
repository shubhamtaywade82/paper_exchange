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

      # Prod-hardening (NEW-38, additive): batch-fetch mark prices for a set
      # of symbols in ONE Redis round-trip (HMGET) instead of N sequential
      # HGETs. Used by read paths that project many positions at once
      # (PositionProjection#for_account previously issued N Redis GETs per
      # /api/positions call). Symbols with no stored price are absent from
      # the returned hash — callers fall back to pos.current_price as before.
      def bulk_get(symbols)
        keys = Array(symbols).map { |s| normalize(s) }
        return {} if keys.empty?

        raw = with_redis { |r| r.hmget(REDIS_KEY, keys) }
        return {} if raw.nil? # Redis unavailable

        keys.zip(raw).each_with_object({}) do |(key, val), acc|
          acc[key] = val.to_f if val
        end
      end

      # Prod-hardening (NEW-12, additive): a lightweight reachability probe
      # for endpoints that MUST refuse to act when Redis is down — notably
      # POST /api/mark_prices, whose liquidation side-effects become
      # cross-process inconsistent if the write silently no-ops. Returns
      # true when Redis answers PING, false otherwise. Cheaper than a full
      # command because PING has no disk/replication cost; safe to call once
      # at the top of a request.
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
