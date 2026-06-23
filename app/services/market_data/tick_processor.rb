module MarketData
  class TickProcessor
    def initialize(redis:)
      @redis = redis
      @stream = "paper_exchange:market:ticks"
    end

    def enqueue(event)
      @redis.xadd(@stream, event.to_h, id: "*", maxlen: 100_000, approximate: true)
    end

    def read_last(count: 100)
      messages = @redis.xrevrange(@stream, count: count)
      messages.map do |id, data|
        MarketEvent.new(
          symbol: data["symbol"],
          price: data["price"]&.to_f,
          quantity: data["quantity"]&.to_i,
          bid: data["bid"]&.to_f,
          ask: data["ask"]&.to_f,
          ltp: data["ltp"]&.to_f,
          timestamp: Time.parse(data["timestamp"]),
          source: data["source"] || "feed"
        )
      end
    end
  end
end
