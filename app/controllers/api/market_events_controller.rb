module Api
  class MarketEventsController < BaseController
    # The feed owner (bot/agent that owns the exchange connections)
    # pushes ticks here — they land in the Redis stream via
    # MarketData::TickProcessor, the shared read spine for strategy
    # context, future candle building, and the GET read-back below.
    # Mark prices remain a separate channel (POST /api/mark_prices):
    # they drive liquidation checks and belong in the hot store, not the
    # history stream.
    #
    # Payload — single tick:
    #   { "symbol": "BTCUSDT", "price": "65123.45", "bid": "65120.0",
    #     "ask": "65125.0", "quantity": "0.5", "ltp": "65123.45",
    #     "timestamp": "2026-09-26T10:00:00Z", "source": "binance" }
    # or a batch: { "events": [ { ... }, { ... } ] } (max 500).
    # At least one of price/ltp/bid/ask is required; all provided prices
    # must be finite, positive and <= MAX_PRICE — same boundary rules as
    # mark_prices (audit M3): a malformed tick rejects the WHOLE request
    # 422 and nothing is enqueued.
    #
    # 503 (not 201) when the tick stream is unavailable — the feed owner
    # must know ticks are being dropped, not silently succeed.
    MAX_PRICE = 1e15
    MAX_QUANTITY = 1e15
    MAX_BATCH = 500
    DEFAULT_COUNT = 100
    MAX_COUNT = 1000

    class InvalidInput < StandardError; end

    def create
      raw_events = params[:events].present? ? Array(params[:events]) : [ params[:market_event].presence || params ]
      raise InvalidInput, "at least one market event is required" if raw_events.blank?
      raise InvalidInput, "batch too large: max #{MAX_BATCH} events per request, got #{raw_events.size}" if raw_events.size > MAX_BATCH

      parsed, invalid = raw_events.each_with_object([ [], [] ]) do |raw, (ok, bad)|
        event, error = parse_event(raw)
        error ? bad << error : ok << event
      end

      if invalid.any?
        return render_error(
          :unprocessable_content,
          "invalid market event(s): #{invalid.join('; ')} — each event needs a symbol (A-Z0-9._-, max 32 chars), at least one of price/ltp/bid/ask (finite, > 0), and a parseable timestamp if given"
        )
      end

      accepted = parsed.map do |event|
        stream_id = MarketData::TickProcessor.enqueue(event)
        raise StreamUnavailable, "tick stream unavailable — ticks were NOT enqueued" if stream_id.nil?

        { stream_id: stream_id }.merge(event.to_h)
      end

      render json: { accepted: accepted.size, data: accepted }, status: :created
    rescue StreamUnavailable => e
      render_error(:service_unavailable, e.message)
    rescue InvalidInput => e
      render_error(:unprocessable_content, e.message)
    end

    # GET /api/market_events?symbol=BTCUSDT&count=50&before=<cursor>
    # — newest-first read-back from the tick stream (capped ~100k
    # entries). `next_cursor` continues where this page stopped.
    def index
      count = read_count
      symbol = params[:symbol].presence&.upcase
      events, next_cursor = MarketData::TickProcessor.read_last(
        count: count, symbol: symbol, before_id: params[:before].presence
      )
      render json: { data: events.map { |e| event_json(e) }, next_cursor: next_cursor }
    end

    private

    class StreamUnavailable < StandardError; end

    def read_count
      requested = Integer(params[:count], exception: false)
      return DEFAULT_COUNT if requested.nil? || requested < 1

      requested.clamp(1, MAX_COUNT)
    end

    # Returns [MarketEvent, nil] on success or [nil, "symbol: reason"].
    def parse_event(raw)
      unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)
        return [ nil, "#{raw.inspect} is not a tick object" ]
      end

      symbol = raw_symbol(raw)
      return [ nil, "missing or invalid symbol (A-Z0-9._-, max 32 chars)" ] unless symbol

      prices = {}
      { price: :price, ltp: :ltp, bid: :bid, ask: :ask }.each do |field, key|
        value = parse_optional_price(raw[field])
        return [ nil, "#{symbol}: invalid #{key} #{raw[field].inspect}" ] if value == :invalid

        prices[field] = value
      end
      return [ nil, "#{symbol}: at least one of price/ltp/bid/ask is required" ] if prices.values.compact.empty?

      quantity = parse_optional_quantity(raw[:quantity])
      return [ nil, "#{symbol}: invalid quantity #{raw[:quantity].inspect}" ] if quantity == :invalid

      timestamp = parse_optional_timestamp(raw[:timestamp])
      return [ nil, "#{symbol}: invalid timestamp #{raw[:timestamp].inspect}" ] if timestamp == :invalid

      [ MarketData::MarketEvent.new(
        symbol: symbol,
        price: prices[:price], ltp: prices[:ltp], bid: prices[:bid], ask: prices[:ask],
        quantity: quantity, timestamp: timestamp,
        source: raw[:source].presence&.to_s&.slice(0, 32) || "api"
      ), nil ]
    end

    def raw_symbol(raw)
      symbol = raw[:symbol].presence&.to_s&.strip&.upcase
      symbol if symbol&.match?(/\A[A-Z0-9._-]{1,32}\z/)
    end

    def parse_optional_price(raw)
      return nil if raw.blank?
      return :invalid unless raw.is_a?(Numeric) || raw.is_a?(String)

      value = Float(raw, exception: false)
      (value.is_a?(Numeric) && value.finite? && value.positive? && value <= MAX_PRICE) ? value : :invalid
    end

    def parse_optional_quantity(raw)
      return nil if raw.blank?
      return :invalid unless raw.is_a?(Numeric) || raw.is_a?(String)

      value = Float(raw, exception: false)
      (value.is_a?(Numeric) && value.finite? && value >= 0 && value <= MAX_QUANTITY) ? value : :invalid
    end

    def parse_optional_timestamp(raw)
      return Time.current if raw.blank?
      return :invalid unless raw.is_a?(String)

      begin
        Time.zone.parse(raw)
      rescue ArgumentError
        nil
      end || :invalid
    end

    def event_json(event)
      {
        symbol: event.symbol,
        price: event.price,
        quantity: event.quantity,
        bid: event.bid,
        ask: event.ask,
        ltp: event.ltp,
        timestamp: event.timestamp,
        source: event.source
      }
    end
  end
end
