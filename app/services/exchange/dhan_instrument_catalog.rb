module Exchange
  class DhanInstrumentCatalog
    # Dhan exchangeSegment enum values relevant to Indian markets
    SEGMENTS = {
      idx: 0,           # IDX_I - Index Value
      nse_eq: 1,        # NSE_EQ - Equity Cash
      nse_fno: 2,       # NSE_FNO - Futures & Options
      nse_currency: 3,  # NSE_CURRENCY - Currency
      bse_eq: 4,        # BSE_EQ - Equity Cash
      mcx: 5,           # MCX_COMM - Commodity
      bse_currency: 7,  # BSE_CURRENCY - Currency
      bse_fno: 8        # BSE_FNO - Futures & Options
    }.freeze

    # Dhan instrumentType values
    INSTRUMENT_TYPES = %w[
      INDEX
      FUTIDX
      OPTIDX
      EQUITY
      FUTSTK
      OPTSTK
      FUTCOM
      OPTFUT
      FUTCUR
      OPTCUR
    ].freeze

    # Index underlyings that are only tradeable via F&O derivatives.
    # Must use FUTIDX/OPTIDX on NSE_FNO(2) or BSE_FNO(8), never INDEX or EQUITY.
    INDEX_UNDERLYINGS = %w[
      NIFTY
      BANKNIFTY
      SENSEX
      FINNIFTY
      MIDCPNIFTY
      NIFTYNXT50
    ].freeze

    # Map index symbol -> allowed exchange segments for F&O trading
    INDEX_FNO_SEGMENTS = [SEGMENTS[:nse_fno], SEGMENTS[:bse_fno]].freeze

    class << self
      def index_underlying?(symbol)
        symbol = symbol.to_s.upcase.strip
        INDEX_UNDERLYINGS.include?(symbol)
      end

      # Indices are never tradeable as cash/spot (INDEX or EQUITY instrument type).
      # They must be traded as FUTIDX or OPTIDX on NSE_FNO/BSE_FNO segments only.
      def derivative_only?(symbol)
        index_underlying?(symbol)
      end

      def valid_instrument_types(symbol)
        return %w[FUTIDX OPTIDX] if index_underlying?(symbol)
        INSTRUMENT_TYPES
      end

      def valid_segments(symbol, instrument_type:)
        return INDEX_FNO_SEGMENTS if index_underlying?(symbol) && %w[FUTIDX OPTIDX].include?(instrument_type)
        SEGMENTS.values
      end

      # Enforce the hard rule: index underlyings cannot be cash/spot traded
      def validate_tradeable!(symbol:, instrument_type:, exchange_segment:)
        return unless index_underlying?(symbol)

        unless %w[FUTIDX OPTIDX].include?(instrument_type)
          raise ArgumentError, "Index #{symbol} is derivative-only. Allowed instrument types: FUTIDX, OPTIDX only. Got: #{instrument_type}"
        end

        unless INDEX_FNO_SEGMENTS.include?(exchange_segment)
          raise ArgumentError, "Index #{symbol} must trade on NSE_FNO(2) or BSE_FNO(8). Got segment: #{exchange_segment}"
        end
      end
    end
  end
end
