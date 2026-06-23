module Domains
  module MarketData
    class OptionChainService
      def initialize
        @chains = {}
      end

      def store(underlying:, expiry_date:, chain:)
        @chains[[underlying, expiry_date]] = chain
      end

      def for(underlying:, expiry_date:)
        @chains[[underlying, expiry_date]]
      end
    end
  end
end
