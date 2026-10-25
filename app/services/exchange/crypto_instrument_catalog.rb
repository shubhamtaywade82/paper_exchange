module Exchange
  # Instrument-type vocabulary for crypto derivatives (Binance USD-M and
  # Binance Options, CoinDCX). Kept separate from Exchange::DhanInstrumentCatalog,
  # whose INSTRUMENT_TYPES enum is delegated from the DhanHQ gem and is
  # India-specific (EQUITY/FUTIDX/OPTIDX/...) with no crypto equivalent.
  class CryptoInstrumentCatalog
    PERPETUAL = "CRYPTO_PERPETUAL".freeze
    # USDT-settled European crypto options (Binance Options symbology,
    # e.g. BTC-261030-81000-C). Long premium only: the order validator
    # refuses any sell that does not reduce an existing long, so the
    # account can never write (sell to open) an option.
    OPTION = "CRYPTO_OPTION".freeze
    INSTRUMENT_TYPES = [ PERPETUAL, OPTION ].freeze

    # Binance Options contracts expire at 08:00 UTC on their expiry date.
    OPTION_EXPIRY_HOUR_UTC = 8
    # <BASE>-<YYMMDD>-<STRIKE>-<C|P>
    OPTION_SYMBOL = /\A(?<base>[A-Z0-9]+)-(?<expiry>\d{6})-(?<strike>\d+(?:\.\d+)?)-(?<right>[CP])\z/

    OptionSymbol = Struct.new(:base, :expiry_date, :strike, :option_type, keyword_init: true) do
      # Binance Options quotes its underlyings against USDT (BTCUSDT, ETHUSDT, ...).
      def underlying
        "#{base}USDT"
      end
    end

    # Returns nil for anything that is not a well-formed option symbol,
    # including an impossible calendar date.
    def self.parse_option_symbol(symbol)
      match = OPTION_SYMBOL.match(symbol.to_s.upcase.strip)
      return nil unless match

      expiry = Date.strptime(match[:expiry], "%y%m%d")
      OptionSymbol.new(
        base: match[:base],
        expiry_date: expiry,
        strike: BigDecimal(match[:strike]),
        option_type: match[:right] == "C" ? "CE" : "PE"
      )
    rescue Date::Error
      nil
    end

    def self.option_underlying(symbol)
      parse_option_symbol(symbol)&.underlying
    end

    def self.option_expires_at(expiry_date)
      Time.utc(expiry_date.year, expiry_date.month, expiry_date.day, OPTION_EXPIRY_HOUR_UTC)
    end
  end
end
