module Domains
  module MarketData
    class GreeksService
      def fetch(symbol, option_type:, strike:)
        OptionSnapshot.where(
          symbol: symbol,
          option_type: option_type,
          strike_price: strike
        ).order(snapshot_at: :desc).first
      end
    end
  end
end
