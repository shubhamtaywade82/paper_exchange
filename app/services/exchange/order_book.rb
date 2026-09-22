module Exchange
  class OrderBook
    def initialize(mutex, books)
      @mutex = mutex
      @books = books
    end

    def apply_snapshot(symbol, bid:, ask:, ltp:, depth: nil, timestamp: Time.current)
      @mutex.synchronize do
        @books[symbol] = {
          bid: bid,
          ask: ask,
          ltp: ltp,
          depth: depth || default_depth(bid, ask),
          updated_at: timestamp
        }
      end
    end

    def snapshot(symbol)
      @mutex.synchronize { (@books[symbol] || default_book(symbol)).dup.freeze }
    end

    def best_bid(symbol)
      snapshot(symbol)&.dig(:bid)
    end

    def best_ask(symbol)
      snapshot(symbol)&.dig(:ask)
    end

    def ltp(symbol)
      snapshot(symbol)&.dig(:ltp)
    end

    def depth(symbol)
      snapshot(symbol)&.dig(:depth)
    end

    private

    # No live snapshot has been applied to this in-process order book for
    # `symbol`. Falls back to the last price the trading agent pushed via
    # POST /api/mark_prices (MarketData::MarkPriceStore) when one exists.
    # In production, refuses to fabricate a price — a market order against a
    # hallucinated book is a hallucinated fill (a $1 spread at $100 was the
    # previous default; for a 1000-share RELIANCE order at ₹2,500 that's a
    # ₹24M accounting hole). Tests keep the stub because they exercise the
    # matching engine without spinning up a market-data feed.
    def default_book(symbol)
      mark_price = MarketData::MarkPriceStore.get(symbol)
      unless mark_price
        raise "No market data for #{symbol}. Push a tick via PaperExchange#market_event or POST /api/mark_prices before submitting orders." unless Rails.env.test?
        return { bid: 100.0, ask: 101.0, ltp: 100.5, depth: default_depth(100.0, 101.0) }
      end

      spread = mark_price * 0.0002
      bid = mark_price - spread
      ask = mark_price + spread
      { bid: bid, ask: ask, ltp: mark_price, depth: default_depth(bid, ask) }
    end

    def default_depth(bid, ask)
      {
        bids: Array([[bid, 100]]),
        asks: Array([[ask, 100]])
      }
    end
  end
end
