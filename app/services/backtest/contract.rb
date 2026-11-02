module Backtest
  # The single instrument a run trades. A dataset is one contract, so a run is
  # one contract. Multi-instrument portfolios are not modelled.
  class Contract
    OPTION_INSTRUMENTS = %w[OPTIDX OPTSTK OPTCUR CRYPTO_OPTION].freeze

    attr_reader :symbol, :instrument_type, :option_type, :strike_price,
      :expiry_date, :currency, :timeframe, :first_bar_at, :last_bar_at

    def initialize(symbol:, instrument_type:, currency:, timeframe:, first_bar_at:, last_bar_at:,
      option_type: nil, strike_price: nil, expiry_date: nil)
      @symbol = symbol
      @instrument_type = instrument_type
      @currency = currency
      @timeframe = timeframe
      @first_bar_at = first_bar_at
      @last_bar_at = last_bar_at
      @option_type = option_type
      @strike_price = strike_price
      @expiry_date = expiry_date
    end

    def self.from_dataset(dataset)
      new(
        symbol: dataset.symbol,
        instrument_type: dataset.instrument_type,
        currency: dataset.currency,
        timeframe: dataset.timeframe,
        first_bar_at: dataset.first_bar_at,
        last_bar_at: dataset.last_bar_at,
        option_type: dataset.option_type,
        strike_price: dataset.strike_price,
        expiry_date: dataset.expiry_date
      )
    end

    # Options are bought, never written. Shorts on an option contract are
    # rejected everywhere the engine decides a side.
    def option?
      OPTION_INSTRUMENTS.include?(instrument_type) || option_type.present?
    end

    def crypto?
      instrument_type.start_with?("CRYPTO_")
    end

    def leverage_allowed?
      instrument_type == "CRYPTO_PERPETUAL"
    end

    def expired_at?(time)
      expiry_date.present? && time.to_date > expiry_date
    end

    # The contract identity used by PaperPosition / PaperOrder rows.
    def order_attributes
      {
        symbol: symbol,
        instrument_type: instrument_type,
        option_type: option_type,
        strike_price: strike_price,
        expiry_date: expiry_date
      }.compact
    end
  end
end
