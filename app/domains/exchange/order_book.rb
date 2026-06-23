module Domains
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
        @mutex.synchronize { @books[symbol]&.dup&.freeze }
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

      def default_depth(bid, ask)
        {
          bids: Array([[bid, 100]]),
          asks: Array([[ask, 100]])
        }
      end
    end
  end
end
