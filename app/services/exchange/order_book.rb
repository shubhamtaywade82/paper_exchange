module Exchange
  # In-process top-of-book for the live matching path.
  #
  # Depth is stored only when the feed supplies it, and nothing is invented
  # to fill the gap. The matching path reads top of book, so a missing depth
  # has no effect on fills; it is nil, not a fabricated 100-unit level.
  class OrderBook
    def initialize(mutex, books)
      @mutex = mutex
      @books = books
    end

    def apply_snapshot(symbol, bid:, ask:, ltp:, depth: nil, timestamp: Clock.now)
      @mutex.synchronize do
        @books[symbol] = {
          bid: bid,
          ask: ask,
          ltp: ltp,
          depth: depth,
          source: :feed,
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

    # No feed snapshot exists for `symbol` in this process. Production falls
    # back to the last price the trading agent pushed (MarketData::MarkPriceStore)
    # and labels the book `:mark_derived`: the bid and ask are a 2 bp model around
    # that price, not observed quotes, and there is no depth. With no mark
    # either, production refuses to price the order at all. Test builds a fixed
    # book so matching can be exercised without a feed.
    def default_book(symbol)
      mark_price = MarketData::MarkPriceStore.get(symbol)
      unless mark_price
        raise "No market data for #{symbol}. Push a tick via PaperExchange#market_event or POST /api/mark_prices before submitting orders." unless Rails.env.test?

        return { bid: 100.0, ask: 101.0, ltp: 100.5, depth: nil, source: :test_fixture }
      end

      spread = mark_price * 0.0002
      bid = mark_price - spread
      ask = mark_price + spread
      { bid: bid, ask: ask, ltp: mark_price, depth: nil, source: :mark_derived }
    end
  end
end
