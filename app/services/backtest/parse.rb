module Backtest
  # Boundary parsing for external values (API params, CSV cells). Returns nil
  # instead of raising so each validator can report the offending field by
  # name. Money is BigDecimal end-to-end: nothing here ever parses to Float.
  module Parse
    TIME_WITH_OFFSET = /(?:Z|[+-]\d{2}:?\d{2})\z/i

    module_function

    def decimal(value)
      return nil if value.nil?
      return nil if value.is_a?(String) && value.strip.empty?

      number = BigDecimal(value.to_s)
      number.finite? ? number : nil
    rescue ArgumentError, TypeError
      nil
    end

    def positive_decimal(value)
      number = decimal(value)
      number if number&.positive?
    end

    # Accepts epoch seconds (Integer or digit-only String) or ISO8601 with an
    # explicit offset. A naive timestamp is rejected: it would silently
    # depend on the server's time zone.
    def time(value)
      case value
      when Integer
        Time.at(value).utc
      when String
        text = value.strip
        if text.match?(/\A\d+\z/)
          Time.at(text.to_i).utc
        elsif text.match?(TIME_WITH_OFFSET)
          Time.iso8601(text).utc
        end
      end
    rescue ArgumentError
      nil
    end
  end
end
