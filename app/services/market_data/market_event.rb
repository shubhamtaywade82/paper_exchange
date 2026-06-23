module MarketData
  class MarketEvent
    attr_reader :symbol, :price, :quantity, :bid, :ask, :ltp, :timestamp, :source

    def initialize(symbol:, price: nil, quantity: nil, bid: nil, ask: nil, ltp: nil, timestamp: Time.current, source: "feed")
      @symbol = symbol
      @price = price
      @quantity = quantity
      @bid = bid
      @ask = ask
      @ltp = ltp || price
      @timestamp = timestamp
      @source = source
    end

    def to_h
      {
        symbol: symbol,
        price: price,
        quantity: quantity,
        bid: bid,
        ask: ask,
        ltp: ltp,
        timestamp: timestamp,
        source: source
      }
    end
  end
end
