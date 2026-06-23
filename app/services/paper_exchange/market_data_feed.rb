module PaperExchange
  class MarketDataFeed
    def initialize
      @books = {}
      @mutex = Mutex.new
    end

    def update(symbol, bid:, ask:, ltp:, depth: nil, timestamp: Time.current)
      @mutex.synchronize do
        @books[symbol] = {
          bid: bid,
          ask: ask,
          ltp: ltp,
          depth: depth || default_depth(bid, ask),
          timestamp: timestamp
        }
      end
    end

    def snapshot(symbol)
      @mutex.synchronize { @books[symbol] }
    end

    def ltp(symbol)
      snapshot(symbol)&.dig(:ltp)
    end

    def best_bid(symbol)
      snapshot(symbol)&.dig(:bid)
    end

    def best_ask(symbol)
      snapshot(symbol)&.dig(:ask)
    end

    private

    def default_depth(bid, ask)
      {
        bids: [[bid, 100]],
        asks: [[ask, 100]]
      }
    end
  end
end
