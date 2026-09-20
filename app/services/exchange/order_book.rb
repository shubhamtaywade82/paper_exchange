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
    # `symbol` (e.g. a fresh Exchange::PaperExchange instance, as controllers
    # create per-request). Falls back to the live Binance mark price from
    # MarketData::MarkPriceStore when one exists — crypto futures symbols
    # always have one once bin/market_data_daemon is running — and only
    # drops to the static equity stub otherwise (unchanged behavior for
    # symbols with no market data feed at all, e.g. in specs).
    def default_book(symbol)
      mark_price = MarketData::MarkPriceStore.get(symbol)
      return { bid: 100.0, ask: 101.0, ltp: 100.5, depth: default_depth(100.0, 101.0) } unless mark_price

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
