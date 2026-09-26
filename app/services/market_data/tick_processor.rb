module MarketData
  # The market tick stream — the read/write spine for everything that
  # consumes live ticks beyond the latest mark price (strategy signals,
  # candle building, the GET /api/market_events debug window).
  #
  # Backed by a capped Redis stream (~100k entries, trimmed
  # approximately) so every process sees the same history. Ticks are
  # written by POST /api/market_events — the bot/agent owns the exchange
  # connections and pushes what it sees — and read newest-first with
  # `read_last`, which supports a `before_id` cursor for paging through
  # the stream (xrevrange exclusive upper bound).
  #
  # A Redis outage degrades to "enqueue returns nil / reads return []"
  # rather than raising into callers (same resilience contract as
  # MarketData::MarkPriceStore) — the API layer turns a nil enqueue into
  # a 503 so the feed owner knows ticks are being dropped.
  class TickProcessor
    STREAM = "paper_exchange:market:ticks"
    MAX_STREAM_LENGTH = 100_000

    class << self
      # Appends one tick. Returns the Redis stream id (ms-seq), or nil
      # when Redis is unavailable. Nil-valued fields are omitted; values
      # are stored as strings (timestamps as ISO8601 with microseconds).
      def enqueue(event)
        payload = event.to_h.compact.transform_values do |value|
          value.is_a?(Time) ? value.iso8601(6) : value.to_s
        end
        with_redis do |redis|
          redis.xadd(STREAM, payload, id: "*", maxlen: MAX_STREAM_LENGTH, approximate: true)
        end
      end

      # Reads up to `count` ticks, newest first, optionally filtered by
      # symbol and/or continued from a `before_id` cursor returned by a
      # previous call.
      #
      # Returns [events, next_cursor]: next_cursor is the stream id to
      # pass as before_id to continue, or nil when the stream is
      # exhausted. With a symbol filter a wider window (10x, capped at
      # 10_000) is read before filtering, so a sparse symbol still gets a
      # full page — the tradeoff is documented: older ticks of a very
      # sparse symbol may require several cursor walks to reach.
      def read_last(count: 100, symbol: nil, before_id: nil)
        window = symbol ? [ count * 10, 10_000 ].min : count
        messages = with_redis do |redis|
          redis.xrevrange(STREAM, before_id ? "(#{before_id}" : "+", count: window + 1)
        end || []

        has_more = messages.size > window
        messages = messages.first(window)

        events = messages.map { |id, data| build_event(data) }
        events = events.select { |event| event.symbol == symbol.to_s.upcase } if symbol

        [ events.first(count), has_more ? messages.last&.first : nil ]
      end

      private

      def build_event(data)
        MarketEvent.new(
          symbol: data["symbol"].to_s.upcase,
          price: data["price"]&.to_f,
          quantity: data["quantity"]&.to_f,
          bid: data["bid"]&.to_f,
          ask: data["ask"]&.to_f,
          ltp: data["ltp"]&.to_f,
          timestamp: data["timestamp"].present? ? Time.zone.parse(data["timestamp"]) : Time.current,
          source: data["source"].presence || "feed"
        )
      end

      def redis
        @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
      end

      def with_redis
        yield redis
      rescue Redis::BaseError => e
        Rails.logger.warn("[TickProcessor] Redis unavailable (#{e.message}) — tick stream skipped") if defined?(Rails)
        nil
      end
    end
  end
end
