module Exchange
  class LatencyEngine
    def initialize(min_ms: 100, max_ms: 500)
      @min_ms = min_ms
      @max_ms = max_ms
    end

    def simulate
      delay = rand(@min_ms..@max_ms) / 1000.0
      sleep(delay)
    end

    def offset_from(signal_time)
      signal_time + rand(@min_ms..@max_ms) / 1000.0
    end

    # Public: sleep for approximately ms milliseconds and yield block.
    def delay(ms)
      sleep([ms / 1000.0, 0.001].max)
      yield if block_given?
      self
    end
  end
end
