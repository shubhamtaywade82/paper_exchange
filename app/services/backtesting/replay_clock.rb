module Backtesting
  # Explicit simulation clock. Never patches Time.now or Time.current globally.
  class ReplayClock
    attr_reader :now

    def initialize(start_at:)
      @now = coerce_time(start_at)
    end

    def advance!(timestamp)
      candidate = coerce_time(timestamp)
      raise ArgumentError, "replay clock cannot move backwards" if candidate < now
      @now = candidate
    end

    private

    def coerce_time(value)
      (value.is_a?(Time) ? value : Time.iso8601(value.to_s)).utc
    rescue ArgumentError, TypeError
      raise ArgumentError, "timestamp must be a Time or ISO-8601 value"
    end
  end
end
