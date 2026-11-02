require "csv"
require "digest"

module Backtest
  # Validates an uploaded OHLC series before anything is stored. Accepts bars
  # as a JSON array (objects or [ts, o, h, l, c, v] rows) or as CSV text with a
  # header row.
  #
  # Rejected, not silently repaired:
  #   * non-finite, zero or negative prices; negative volume
  #   * OHLC inconsistent with itself (high below open/close, low above them)
  #   * timestamps without an explicit offset, or duplicate timestamps
  #   * a currency that does not match the instrument's settlement currency
  #   * option instruments without option_type, strike and expiry
  #
  # Rows are sorted by time before storage. Input order is not part of the
  # contract.
  module DatasetValidator
    class Invalid < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = Array(errors)
        super(@errors.first(20).join("; "))
      end
    end

    VENUES = %w[paper binance_usdm coindcx_futures].freeze
    MIN_BARS = 2
    MAX_ERRORS = 20
    CSV_HEADERS = %w[bar_at open high low close volume].freeze

    module_function

    def max_bars
      Integer(ENV.fetch("PAPER_EXCHANGE_BACKTEST_MAX_BARS", "500000"))
    end

    def call(params)
      h = params.to_h.symbolize_keys
      errors = []

      name = h[:name].to_s.strip
      errors << "name is required (max 120 characters)" if name.empty? || name.length > 120

      symbol = h[:symbol].to_s.strip.upcase
      errors << "symbol is required" if symbol.empty?

      venue = (h[:venue].presence || "paper").to_s
      errors << "venue must be one of #{VENUES.join(', ')}" unless VENUES.include?(venue)

      instrument_type = h[:instrument_type].to_s.upcase
      expected_currency = Risk::CurrencyValidator::INSTRUMENT_CURRENCY[instrument_type]
      errors << "instrument_type #{instrument_type.inspect} is not supported" if expected_currency.nil?
      if Exchange::DhanInstrumentCatalog.index_underlying?(symbol) && !%w[FUTIDX OPTIDX].include?(instrument_type)
        # The live OrderValidator rejects every index order that is not F&O. Refuse the dataset now.
        errors << "indices trade only as FUTIDX or OPTIDX, not #{instrument_type.inspect}"
      end

      currency = (h[:currency].presence || expected_currency).to_s.upcase
      if expected_currency && currency != expected_currency
        errors << "currency must be #{expected_currency} for #{instrument_type}, got #{currency}"
      end

      timeframe = h[:timeframe].to_s
      errors << "timeframe must be one of #{Timeframe::SUPPORTED.join(', ')}" unless Timeframe::SUPPORTED.include?(timeframe)

      option_type, strike_price, expiry_date, option_errors = option_fields(h, instrument_type)
      errors.concat(option_errors)

      candles, bar_errors = parse_bars(h)
      errors.concat(bar_errors)
      errors << "at least #{MIN_BARS} bars are required" if candles.size < MIN_BARS && bar_errors.empty?

      raise Invalid, errors if errors.any?

      attributes = {
        name: name,
        symbol: symbol,
        venue: venue,
        instrument_type: instrument_type,
        currency: currency,
        timeframe: timeframe,
        option_type: option_type,
        strike_price: strike_price,
        expiry_date: expiry_date,
        bars_count: candles.size,
        first_bar_at: candles.first.bar_at,
        last_bar_at: candles.last.bar_at,
        fingerprint: fingerprint(symbol, instrument_type, timeframe, option_type, strike_price, expiry_date, candles)
      }

      { attributes: attributes, candles: candles }
    end

    def option_fields(h, instrument_type)
      option_type = h[:option_type].presence&.to_s&.upcase
      strike_price = Parse.positive_decimal(h[:strike_price])
      expiry_date = h[:expiry_date].present? ? parse_date(h[:expiry_date]) : nil
      errors = []

      if Contract::OPTION_INSTRUMENTS.include?(instrument_type)
        errors << "option_type must be CE or PE for #{instrument_type}" unless %w[CE PE].include?(option_type)
        errors << "strike_price is required for #{instrument_type}" if strike_price.nil?
        errors << "expiry_date (YYYY-MM-DD) is required for #{instrument_type}" if expiry_date.nil?
      elsif option_type.present? || strike_price || expiry_date
        errors << "option fields are only valid for option instruments, not #{instrument_type.inspect}"
      end

      [ option_type, strike_price, expiry_date, errors ]
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def parse_bars(h)
      raw_rows = if h[:csv].present?
        parse_csv(h[:csv])
      elsif h[:bars].is_a?(Array)
        h[:bars]
      else
        return [ [], [ "either bars (array) or csv (text) must be provided" ] ]
      end

      return [ [], [ "too many bars: #{raw_rows.size} exceeds the limit of #{max_bars}" ] ] if raw_rows.size > max_bars

      errors = []
      candles = []
      raw_rows.each_with_index do |row, index|
        candle, error = parse_row(row)
        if error
          errors << "bar #{index + 1}: #{error}" if errors.size < MAX_ERRORS
        else
          candles << candle
        end
      end
      return [ [], errors ] if errors.any?

      candles.sort_by!(&:bar_at)
      candles.each_cons(2) do |previous, current|
        if previous.bar_at == current.bar_at
          errors << "duplicate bar_at #{current.bar_at.iso8601}"
          break
        end
      end
      [ candles, errors ]
    rescue CSV::MalformedCSVError => e
      [ [], [ "csv is malformed: #{e.message}" ] ]
    end

    def parse_csv(text)
      rows = CSV.parse(text.to_s, headers: true)
      missing = CSV_HEADERS.first(5) - rows.headers.to_a.compact
      raise Invalid, [ "csv header must include #{CSV_HEADERS.first(5).join(', ')}" ] if missing.any?

      rows.map(&:to_h)
    end

    def parse_row(row)
      values = case row
      when Array
        ts, open, high, low, close, volume = row
        { bar_at: ts, open: open, high: high, low: low, close: close, volume: volume }
      when Hash
        h = row.to_h.symbolize_keys
        {
          bar_at: h[:bar_at] || h[:time] || h[:timestamp] || h[:datetime],
          open: h[:open], high: h[:high], low: h[:low], close: h[:close], volume: h[:volume]
        }
      else
        return [ nil, "must be an object or an array" ]
      end

      bar_at = Parse.time(values[:bar_at])
      return [ nil, "bar_at must be epoch seconds or ISO8601 with an offset" ] if bar_at.nil?

      open = Parse.positive_decimal(values[:open])
      high = Parse.positive_decimal(values[:high])
      low = Parse.positive_decimal(values[:low])
      close = Parse.positive_decimal(values[:close])
      return [ nil, "open/high/low/close must be finite positive numbers" ] if [ open, high, low, close ].any?(&:nil?)

      volume = values[:volume].nil? || values[:volume].to_s.strip.empty? ? BigDecimal("0") : Parse.decimal(values[:volume])
      return [ nil, "volume must be a finite number >= 0" ] if volume.nil? || volume.negative?

      if low > [ open, close ].min || high < [ open, close ].max || high < low
        return [ nil, "OHLC is inconsistent (low must be <= open/close <= high)" ]
      end

      [ Candle.new(bar_at, open, high, low, close, volume), nil ]
    end

    def fingerprint(symbol, instrument_type, timeframe, option_type, strike_price, expiry_date, candles)
      header = [ "v1", symbol, instrument_type, timeframe, option_type, strike_price&.to_s("F"), expiry_date&.iso8601 ]
      rows = candles.map do |c|
        [ c.bar_at.iso8601(6), c.open.to_s("F"), c.high.to_s("F"), c.low.to_s("F"), c.close.to_s("F"), c.volume.to_s("F") ].join(",")
      end
      Digest::SHA256.hexdigest((header + rows).join("\n"))
    end
  end
end
