module Strategy
  class IndicatorEngine
    def initialize
      @indicators = {}
    end

    def ingest(event)
      symbol = event.symbol
      @indicators[symbol] ||= {}
      store_price(symbol, event)
      compute_if_ready(symbol)
    end

    def for(symbol)
      @indicators[symbol]
    end

    private

    def store_price(symbol, event)
      series = (@indicators[symbol][:prices] ||= [])
      series << { price: event.ltp, timestamp: event.timestamp }
      @indicators[symbol][:ltp] = event.ltp
      @indicators[symbol][:updated_at] = event.timestamp
    end

    def compute_if_ready(symbol)
      series = @indicators.dig(symbol, :prices) || []
      return unless series.size >= 20

      closes = series.last(20).pluck(:price)
      @indicators[symbol][:sma_20] = closes.sum / closes.size
    end
  end
end
