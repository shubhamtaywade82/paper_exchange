module Exchange
  class LatencyEngine
    def initialize(min_ms: 100, max_ms: 500)
      @min_ms = min_ms
      @max_ms = max_ms
    end

    # Off in test (slows the suite ~10x) and off in production unless
    # PAPER_EXCHANGE_SIMULATE_LATENCY=true is set explicitly. A paper broker
    # that artificially sleeps 100-500ms on every matching call caps Puma
    # throughput at ~2-10 orders/sec/worker — fine for the realism use case
    # it was added for, not fine to leave on by default.
    def simulate
      return if Rails.env.test?
      return unless ENV["PAPER_EXCHANGE_SIMULATE_LATENCY"] == "true"

      sleep(rand(@min_ms..@max_ms) / 1000.0)
    end

    def offset_from(signal_time)
      signal_time + rand(@min_ms..@max_ms) / 1000.0
    end
  end
end
