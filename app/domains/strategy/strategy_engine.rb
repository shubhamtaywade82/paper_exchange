module Domains
  module Strategy
    class StrategyEngine
      def initialize(indicator_engine:, market_structure_engine:, risk_manager: Domains::Risk::RiskManager)
        @indicator_engine = indicator_engine
        @market_structure_engine = market_structure_engine
        @risk_manager = risk_manager
      end

      def evaluate(signal)
        results = @risk_manager.evaluate(account_id: signal.account_id, signal: signal)
        results.empty? ? signal : nil
      end
    end
  end
end
