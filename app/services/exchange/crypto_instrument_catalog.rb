module Exchange
  # Instrument-type vocabulary for crypto perpetual futures (Binance USD-M,
  # CoinDCX). Kept separate from Exchange::DhanInstrumentCatalog, whose
  # INSTRUMENT_TYPES enum is delegated from the DhanHQ gem and is
  # India-specific (EQUITY/FUTIDX/OPTIDX/...) with no crypto equivalent.
  class CryptoInstrumentCatalog
    PERPETUAL = "CRYPTO_PERPETUAL".freeze
    INSTRUMENT_TYPES = [ PERPETUAL ].freeze
  end
end
