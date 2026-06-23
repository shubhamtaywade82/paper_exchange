module Strategy
  class StrategyEngine
    def initialize(indicator_engine:, market_structure_engine:, risk_manager: Risk::RiskManager)
      @indicator_engine = indicator_engine
      @market_structure_engine = market_structure_engine
      @risk_manager = risk_manager
    end

    def evaluate(signal)
      results, _events = @risk_manager.evaluate(account_id: signal.account_id, signal: signal)
      Array(results).empty? ? nil : signal
    end
  end
end
