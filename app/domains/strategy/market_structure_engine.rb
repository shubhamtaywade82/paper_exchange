module Domains
  module Strategy
    class MarketStructureEngine
      def initialize
        @snapshots = {}
      end

      def ingest(symbol, timeframe:, trend: nil, bos: false, choch: false, bullish_fvg_count: 0, bearish_fvg_count: 0)
        @snapshots[symbol] ||= {}
        @snapshots[symbol][timeframe] = {
          trend: trend,
          last_bos: bos,
          last_choch: choch,
          bullish_fvg_count: bullish_fvg_count,
          bearish_fvg_count: bearish_fvg_count,
          as_of: Time.current
        }
      end

      def snapshot(symbol, timeframe: "5m")
        @snapshots.dig(symbol, timeframe)
      end
    end
  end
end
