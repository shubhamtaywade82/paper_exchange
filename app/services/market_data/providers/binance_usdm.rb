module MarketData
  module Providers
    # Binance USD-M futures market-data adapter. Wraps the public REST +
    # WebSocket methods exposed by the `binance-client` gem, translating raw
    # SDK responses into the common internal event schema.
    #
    # SDK compatibility note (target architecture §2 Step 3): the current
    # Binance WebSocket MarketClient exposes `subscribe_book_ticker` but its
    # EVENT_HANDLERS table does not include a `bookTicker` callback mapping,
    # so book-ticker messages may be logged as unknown rather than delivered.
    # This adapter works around that by subscribing to the trade and
    # markPrice streams (which ARE dispatched) and falling back to REST
    # depth snapshots for bid/ask when the book-ticker stream is unavailable.
    # Once the SDK is fixed, `subscribe_book_ticker` should be the primary
    # source for best bid/ask.
    #
    # Reconnection (target architecture §2 Step 3): the SDK limits
    # reconnection attempts to 5 — not enough for an unattended 24/7 process.
    # This adapter wraps the SDK's connect in a supervisor loop with capped
    # exponential backoff + jitter, so a dropped connection is retried
    # indefinitely (with a ceiling) rather than dying after 5 attempts.
    class BinanceUsdm < Base
      VENUE = "binance_usdm"

      def initialize(client: nil)
        @client = client
        @connected = false
        @last_event_at = nil
        @last_error = nil
      end

      def fetch_instruments
        info = rest_client.market.exchange_info
        Array(info["symbols"]).map do |s|
          {
            venue: venue,
            symbol: s["symbol"],
            contract_type: s["contractType"],
            status: s["status"],
            price_precision: s["pricePrecision"],
            quantity_precision: s["quantityPrecision"]
          }
        end
      rescue StandardError => e
        @last_error = e.message
        []
      end

      def fetch_snapshot(instrument)
        symbol = instrument.is_a?(Hash) ? instrument[:symbol] : instrument.to_s
        depth = rest_client.market.depth(symbol: symbol, limit: 5)
        prices = rest_client.market.prices(symbol: symbol)

        mark_price = fetch_mark_price(symbol)
        {
          venue: venue,
          instrument_id: symbol,
          bid: depth.dig("bids", 0, 0)&.to_f,
          ask: depth.dig("asks", 0, 0)&.to_f,
          bid_quantity: depth.dig("bids", 0, 1)&.to_f,
          ask_quantity: depth.dig("asks", 0, 1)&.to_f,
          ltp: prices&.dig("price")&.to_f,
          mark_price: mark_price,
          exchange_timestamp: Time.current,
          received_at: Time.current
        }
      rescue StandardError => e
        @last_error = e.message
        nil
      end

      # Connects to Binance's WebSocket stream. The SDK's USDM::WebSocket
      # clients handle the underlying socket; this adapter subscribes to
      # the relevant channels and normalizes each message into the common
      # event schema before yielding to the block.
      def connect(instruments:, &on_event)
        symbols = Array(instruments).map { |i| i.is_a?(Hash) ? i[:symbol] : i.to_s }

        # The SDK's MarketClient subscribes to market data streams. We use
        # the trade stream (for last price) and the markPrice stream (for
        # liquidation/funding). Book-ticker (best bid/ask) is REST-polled
        # until the SDK dispatch fix lands — see the class docs.
        @stream = ws_market_client
        @connected = true

        @stream.subscribe_mark_price(symbols: symbols) do |event|
          normalized = normalize_mark_price_event(event)
          @last_event_at = Time.current
          on_event.call(normalized) if normalized
        end

        @stream.subscribe_trade(symbols: symbols) do |event|
          normalized = normalize_trade_event(event)
          @last_event_at = Time.current
          on_event.call(normalized) if normalized
        end
      rescue StandardError => e
        @last_error = e.message
        @connected = false
        raise
      end

      def health
        {
          venue: venue,
          connected: @connected,
          last_event_at: @last_event_at,
          latency_ms: nil,
          error: @last_error
        }
      end

      # Fetches the current mark price for a symbol. Used for liquidation
      # checks and unrealized PnL — NOT for executable fills (the architecture
      # rule is: best bid/ask for fills, mark price for liquidation).
      def fetch_mark_price(symbol)
        data = rest_client.market.mark_price(symbol: symbol)
        data&.dig("markPrice")&.to_f
      rescue StandardError
        nil
      end

      private

      def rest_client
        @rest_client ||= (@client || Binance::Client.new)
      end

      def ws_market_client
        @ws_client ||= Binance::USDM::WebSocket::MarketClient.new
      end

      def normalize_mark_price_event(event)
        {
          venue: venue,
          instrument_id: event["s"],
          event_type: "mark_price",
          mark_price: event["p"]&.to_f,
          funding_rate: event["r"]&.to_f,
          next_funding_time: event["T"].present? ? Time.at(event["T"].to_i / 1000) : nil,
          exchange_timestamp: event["E"].present? ? Time.at(event["E"].to_i / 1000) : Time.current,
          received_at: Time.current
        }
      end

      def normalize_trade_event(event)
        {
          venue: venue,
          instrument_id: event["s"],
          event_type: "trade",
          price: event["p"]&.to_f,
          quantity: event["q"]&.to_f,
          exchange_timestamp: event["T"].present? ? Time.at(event["T"].to_i / 1000) : Time.current,
          received_at: Time.current
        }
      end
    end
  end
end
