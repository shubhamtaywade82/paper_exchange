module Strategy
  class StrategyEngine
    def initialize(indicator_engine:, market_structure_engine:, risk_manager: Risk::RiskManager)
      @indicator_engine = indicator_engine
      @market_structure_engine = market_structure_engine
      @risk_manager = risk_manager
    end

    # Boolean-style gate (original contract): the signal if it passes the
    # risk checks, nil otherwise.
    def evaluate(signal)
      results, _events = @risk_manager.evaluate(account_id: signal.account_id, signal: signal)
      Array(results).empty? ? nil : signal
    end

    # Read-only pre-trade assessment for POST /api/strategy/signals:
    # runs the SAME risk gate submit_order runs — RiskManager only
    # decides (audit M5: no persistence here, no order created, no state
    # mutated) — and reports the decision with the per-check outcomes and
    # rejection reasons. 200 either way: the assessment itself succeeded;
    # `decision` carries the answer.
    def assess(signal)
      results, rejections = @risk_manager.evaluate(account_id: signal.account_id, signal: signal)

      {
        decision: rejections.nil? ? "allow" : "reject",
        checks: Array(results).map(&:to_s),
        rejections: Array(rejections).map(&:to_s)
      }
    end
  end
end
