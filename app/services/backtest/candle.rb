module Backtest
  # One OHLC bar as the engine consumes it. `bar_at` is the bar's open time.
  Candle = Struct.new(:bar_at, :open, :high, :low, :close, :volume)
end
