module Exchange
  class DhanInstrumentCatalog
    # Hard-coded index underlyings — indices are derivative-only.
    INDEX_SYMBOLS = %w[NIFTY BANKNIFTY SENSEX FINNIFTY MIDCPNIFTY NIFTYNXT50].freeze

    # Delegate enum to the DhanHQ gem so we stay in sync with the SDK.
    def self.valid_instrument_types
      DhanHQ::Constants::InstrumentType::ALL
    end
    INSTRUMENT_TYPES = valid_instrument_types.freeze

    def self.index_underlying?(symbol)
      INDEX_SYMBOLS.include?(symbol.to_s.upcase)
    end

    # Fetch all instruments for a Dhan exchange segment (e.g. "NSE_FNO", "IDX_I").
    def self.by_segment(exchange_segment)
      DhanHQ::Models::Instrument.by_segment(exchange_segment.to_s)
    end

    # Find a single instrument by segment and symbol.
    def self.find(exchange_segment, symbol)
      DhanHQ::Models::Instrument.find(exchange_segment.to_s, symbol.to_s)
    end

    # Search across all common segments for a symbol.
    def self.find_anywhere(symbol)
      DhanHQ::Models::Instrument.find_anywhere(symbol.to_s)
    end

    # Guard-rails for order placement.
    def self.validate_tradeable!(symbol:, instrument_type:, exchange_segment:)
      instrument = find(exchange_segment.to_s, symbol.to_s)
      raise ArgumentError, "Instrument not found for #{symbol} on #{exchange_segment}" unless instrument

      allowed = if index_underlying?(symbol)
        %w[FUTIDX OPTIDX]
      else
        [
          DhanHQ::Constants::InstrumentType::EQUITY,
          DhanHQ::Constants::InstrumentType::FUTSTK,
          DhanHQ::Constants::InstrumentType::OPTSTK,
          DhanHQ::Constants::InstrumentType::FUTCOM,
          DhanHQ::Constants::InstrumentType::OPTFUT,
          DhanHQ::Constants::InstrumentType::FUTCUR,
          DhanHQ::Constants::InstrumentType::OPTCUR
        ]
      end

      unless allowed.include?(instrument_type)
        raise ArgumentError, "Instrument #{symbol} does not support #{instrument_type}. Allowed: #{allowed.join(", ")}"
      end

      instrument
    end
  end
end
