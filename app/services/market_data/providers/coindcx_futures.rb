module MarketData
  module Providers
    # CoinDCX futures market-data adapter. Wraps the public REST + WebSocket
    # methods exposed by the `coindcx-client` gem, translating raw SDK
    # responses into the common internal event schema.
    #
    # Architecture note (target architecture §2): the CoinDCX SDK exposes
    # futures market-data APIs (list_active_instruments, current_prices,
    # fetch_order_book, list_candlesticks) and a WebSocket client
    # (CoinDCX::WS::SocketIOClient via client.ws). This adapter uses ONLY
    # public market-data methods — it does not use the SDK's private
    # order-placement methods to simulate paper fills.
    #
    # Funding caveat (target architecture §2): the CoinDCX SDK exposes
    # futures market-data APIs, but the perpetual futures funding-rate
    # contract should be verified independently. Do not confuse CoinDCX's
    # lending/funding-order APIs with perpetual futures funding settlement.
    # Until the funding endpoint is verified, this adapter does NOT emit
    # funding events — they should come from the Binance adapter or from
    # the agent pushing POST /api/funding_events.
    class CoindcxFutures < Base
      VENUE = "coindcx_futures"

      def initialize(client: nil)
        @client = client
        @connected = false
        @last_event_at = nil
        @last_error = nil
      end

      def fetch_instruments
        instruments = rest_client.futures.market_data.list_active_instruments
        Array(instruments).map do |inst|
          {
            venue: venue,
            symbol: inst["symbol"] || inst["instrument"],
            status: inst["status"],
            contract_type: inst["contract_type"] || "perpetual"
          }
        end
      rescue StandardError => e
        @last_error = e.message
        []
      end

      def fetch_snapshot(instrument)
        symbol = instrument.is_a?(Hash) ? instrument[:symbol] : instrument.to_s
        book = rest_client.futures.market_data.fetch_order_book(symbol: symbol)
        prices = rest_client.futures.market_data.current_prices(symbol: symbol)

        {
          venue: venue,
          instrument_id: symbol,
          bid: book.dig("bids", 0, "price")&.to_f || book.dig("bids", 0, 0)&.to_f,
          ask: book.dig("asks", 0, "price")&.to_f || book.dig("asks", 0, 0)&.to_f,
          bid_quantity: book.dig("bids", 0, "quantity")&.to_f || book.dig("bids", 0, 1)&.to_f,
          ask_quantity: book.dig("asks", 0, "quantity")&.to_f || book.dig("asks", 0, 1)&.to_f,
          ltp: prices&.first&.dig("last_price")&.to_f,
          mark_price: nil, # CoinDCX mark price API not verified — see class docs
          exchange_timestamp: Time.current,
          received_at: Time.current
        }
      rescue StandardError => e
        @last_error = e.message
        nil
      end

      def connect(instruments:, &on_event)
        symbols = Array(instruments).map { |i| i.is_a?(Hash) ? i[:symbol] : i.to_s }
        @ws_client = rest_client.ws
        @connected = true

        # CoinDCX WebSocket uses a Socket.IO client. Subscribe to the
        # futures trade and order-book channels for the requested symbols.
        @ws_client.on("trade") do |event|
          normalized = normalize_trade_event(event)
          @last_event_at = Time.current
          on_event.call(normalized) if normalized && symbols.include?(normalized[:instrument_id])
        end

        @ws_client.on("orderbook") do |event|
          normalized = normalize_orderbook_event(event)
          @last_event_at = Time.current
          on_event.call(normalized) if normalized && symbols.include?(normalized[:instrument_id])
        end

        @ws_client.connect
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

      private

      def rest_client
        @rest_client ||= (@client || CoinDCX::Client.new)
      end

      def normalize_trade_event(event)
        return nil unless event["symbol"] || event["s"]

        {
          venue: venue,
          instrument_id: event["symbol"] || event["s"],
          event_type: "trade",
          price: (event["price"] || event["p"])&.to_f,
          quantity: (event["quantity"] || event["q"])&.to_f,
          exchange_timestamp: Time.current,
          received_at: Time.current
        }
      end

      def normalize_orderbook_event(event)
        return nil unless event["symbol"] || event["s"]

        {
          venue: venue,
          instrument_id: event["symbol"] || event["s"],
          event_type: "book",
          bid: (event.dig("bids", 0, "price") || event.dig("bids", 0, 0))&.to_f,
          ask: (event.dig("asks", 0, "price") || event.dig("asks", 0, 0))&.to_f,
          bid_quantity: (event.dig("bids", 0, "quantity") || event.dig("bids", 0, 1))&.to_f,
          ask_quantity: (event.dig("asks", 0, "quantity") || event.dig("asks", 0, 1))&.to_f,
          exchange_timestamp: Time.current,
          received_at: Time.current
        }
      end
    end
  end
end
