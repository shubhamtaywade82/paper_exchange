module Backtest
  # Tick and L2 replay primitives (MULTI_MARKET_SPEC §8). Everything here is
  # decimal: a price or quantity is never a Float, so a VWAP or a depth
  # consumption is exact.
  module Tick
    class InvalidEvent < ArgumentError; end

    module_function

    # A Time, or an ISO-8601 string that states its offset. A string without an
    # offset is refused: it would be read as the machine's local time, and replay
    # timestamps must not depend on the machine.
    def coerce_time(value)
      return value.utc if value.is_a?(Time)

      text = value.to_s
      raise ArgumentError, "timestamp must be a Time or an ISO-8601 value with an offset" unless text.match?(/(Z|[+-]\d{2}:?\d{2})\z/i)

      Time.iso8601(text).utc
    rescue ArgumentError, TypeError
      raise ArgumentError, "timestamp must be a Time or an ISO-8601 value with an offset"
    end

    # A finite decimal that is positive, or non-negative when `allow_zero` is set.
    def decimal(value, name, allow_zero: false)
      number = parse_decimal(value, name)
      valid = number.finite? && (allow_zero ? number >= 0 : number.positive?)
      raise ArgumentError, "#{name} must be finite and #{allow_zero ? 'non-negative' : 'positive'}" unless valid

      number
    end

    def parse_decimal(value, name)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{name} must be a finite decimal"
    end
  end
end
