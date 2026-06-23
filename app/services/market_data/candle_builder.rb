module MarketData
  class CandleBuilder
    Event = Struct.new(:symbol, :ltp, :quantity, :timestamp)

    def initialize
      @candles = {}
    end

    def build_from(ticks)
      ticks.each do |tick|
        ingest(Event.new(tick[:symbol], tick[:ltp] || tick[:price], tick[:volume] || tick[:quantity], tick[:timestamp]), timeframe: "5m")
      end
      ticks.empty? ? nil : candles(ticks.first[:symbol]).last
    end

    def ingest(event, timeframe: "5m")
      key = [event.symbol, timeframe]
      @candles[key] ||= []

      bucket = @candles[key].last
      if bucket && bucket[:started_at] == bucket_start(event.timestamp, timeframe)
        candle(bucket, event)
      else
        @candles[key] << new_candle(event, timeframe)
      end
    end

    def candles(symbol, timeframe: "5m")
      (@candles[[symbol, timeframe]] || []).last(200)
    end

    private

    def new_candle(event, timeframe)
      {
        symbol: event.symbol,
        timeframe: timeframe,
        open: event.ltp,
        high: event.ltp,
        low: event.ltp,
        close: event.ltp,
        volume: event.quantity || 0,
        started_at: bucket_start(event.timestamp, timeframe)
      }
    end

    def candle(bucket, event)
      bucket[:close] = event.ltp
      bucket[:high] = [bucket[:high], event.ltp].compact.max
      bucket[:low]  = [bucket[:low], event.ltp].compact.min
      bucket[:volume] += event.quantity || 0
      bucket
    end

    def bucket_start(time, timeframe)
      case timeframe
      when "1m" then time.beginning_of_minute
      when "5m" then time.beginning_of_hour - ((time.min / 5) * 5).minutes
      else time.beginning_of_hour
      end
    end
  end
end
