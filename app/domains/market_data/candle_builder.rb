module Domains
  module MarketData
    class CandleBuilder
      def initialize
        @candles = {}
      end

      def ingest(event, timeframe: "5m")
        key = [event.symbol, timeframe]
        candle(@candles[key] ||= new_candle(event, timeframe), event)
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
end
