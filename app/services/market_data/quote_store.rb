module MarketData
  # Shared, venue-aware quote store. Holds the freshest normalized quote for
  # every (venue, instrument) pair, backed by Redis so every process (web,
  # jobs, market_data) sees the same state. This is the authoritative source
  # for executable quotes (best bid/ask) and mark prices — the matching
  # worker and liquidation engine read through this store.
  #
  # Architecture rule (target architecture §3 "Keep different price types
  # separate"): this store records bid, ask, ltp, mark_price, and exchange
  # timestamp separately. The matching engine uses bid/ask for fills; the
  # liquidation engine uses mark_price; the PnL projection uses mark_price
  # (falling back to ltp). NEVER use the mark price as though it were the
  # best executable quote — they are different things.
  #
  # Staleness (target architecture §3): every quote carries an
  # exchange_timestamp and received_at. Callers can check `stale?` to
  # reject quotes older than a configurable threshold — new risk-increasing
  # orders should be blocked when the required market data is stale.
  class QuoteStore
    REDIS_KEY = "paper_exchange:quotes"
    DEFAULT_STALENESS_THRESHOLD = 30 # seconds

    class << self
      # Writes a normalized quote into the store. The quote Hash must include
      # :venue, :instrument_id, and :exchange_timestamp; bid/ask/ltp/mark_price
      # are all optional but at least one price type should be present.
      def set(quote)
        key = composite_key(quote[:venue], quote[:instrument_id])
        data = quote.merge(received_at: Time.current.iso8601(6))
        with_redis { |r| r.hset(REDIS_KEY, key, data.to_json) }
        # Also mirror the mark_price into the legacy MarkPriceStore so
        # existing callers (liquidation engine, PnL projection) continue
        # to work during the migration.
        if quote[:mark_price]
          MarkPriceStore.set(quote[:instrument_id], quote[:mark_price])
        elsif quote[:ltp]
          MarkPriceStore.set(quote[:instrument_id], quote[:ltp])
        end
        data
      end

      # Returns the freshest quote for a (venue, instrument) pair, or nil.
      def get(venue, instrument_id)
        key = composite_key(venue, instrument_id)
        raw = with_redis { |r| r.hget(REDIS_KEY, key) }
        raw ? parse_quote(raw) : nil
      end

      # Returns the freshest quote across ALL venues for an instrument.
      # If multiple venues serve the same symbol, the most recently received
      # quote wins. This is a convenience for callers that don't care about
      # venue (e.g. the legacy MarkPriceStore fallback path).
      def get_any(instrument_id)
        all_for_instrument(instrument_id).max_by { |q| q[:received_at] }
      end

      # Returns all quotes for one instrument across all venues.
      def all_for_instrument(instrument_id)
        prefix = "#{instrument_id.to_s.upcase}:"
        raw = with_redis { |r| r.hgetall(REDIS_KEY) } || {}
        raw.filter_map do |key, val|
          # Key format is "VENUE:INSTRUMENT" — match by instrument suffix.
          quote = parse_quote(val)
          next unless quote && quote[:instrument_id].to_s.upcase == instrument_id.to_s.upcase
          quote
        end
      end

      # Returns all quotes from one venue (for the exchange status endpoint).
      def all_for_venue(venue)
        raw = with_redis { |r| r.hgetall(REDIS_KEY) } || {}
        raw.filter_map do |key, val|
          quote = parse_quote(val)
          next unless quote && quote[:venue] == venue.to_s
          quote
        end
      end

      # Returns true if the quote is stale (older than threshold seconds).
      # Used by the matching worker and risk gate to reject orders against
      # stale quotes — a stale quote is not a valid executable price.
      def stale?(quote, threshold = DEFAULT_STALENESS_THRESHOLD)
        return true unless quote && quote[:received_at]
        (Time.current - quote[:received_at]) > threshold
      end

      def clear
        with_redis { |r| r.del(REDIS_KEY) }
      end

      private

      def composite_key(venue, instrument_id)
        "#{venue}:#{instrument_id.to_s.upcase}"
      end

      def parse_quote(raw)
        data = JSON.parse(raw)
        {
          venue: data["venue"],
          instrument_id: data["instrument_id"],
          bid: data["bid"]&.to_f,
          ask: data["ask"]&.to_f,
          bid_quantity: data["bid_quantity"]&.to_f,
          ask_quantity: data["ask_quantity"]&.to_f,
          ltp: data["ltp"]&.to_f,
          mark_price: data["mark_price"]&.to_f,
          funding_rate: data["funding_rate"]&.to_f,
          next_funding_time: data["next_funding_time"].present? ? Time.parse(data["next_funding_time"]) : nil,
          exchange_timestamp: data["exchange_timestamp"].present? ? Time.parse(data["exchange_timestamp"]) : nil,
          received_at: data["received_at"].present? ? Time.parse(data["received_at"]) : nil
        }
      rescue JSON::ParserError
        nil
      end

      def with_redis
        yield redis
      rescue Redis::BaseError => e
        Rails.logger.warn("[QuoteStore] Redis unavailable (#{e.message})") if defined?(Rails)
        nil
      end

      def redis
        @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
      end
    end
  end
end
