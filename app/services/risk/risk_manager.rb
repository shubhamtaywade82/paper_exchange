module Risk
  # The risk gate. Decides — never persists (audit M5): rejection events
  # used to be created here, inside the caller's order transaction, and the
  # very raise that rejected the order rolled them back — the entire
  # rejection history the /api/risk_events endpoint exists to serve was
  # silently unwritten. Persistence now lives in PaperExchange#submit_order's
  # post-rollback rescue path.
  #
  # Contract: returns [results, nil] when checks pass, or [[], rejections]
  # where rejections is a non-empty list of *_REJECTED symbols.
  #
  # FAILS CLOSED: a raising validator (a NoMethodError in new validator
  # code, a transient DB hiccup) becomes a synthetic
  # RISK_EVALUATION_ERROR_REJECTED — the order is rejected, never waved
  # through. The old rescue returned [], which destructured to a nil
  # rejection list in submit_order and let the order proceed with ZERO risk
  # checks applied.
  class RiskManager
    class << self
      def evaluate(account_id:, signal:)
        results = VALIDATORS.map do |name, validator|
          next [ :passed, name ] unless validator

          Array(validator.new.evaluate(account_id, signal))
        end.flatten(2)

        events = results.select { |r| r.is_a?(Symbol) && r.to_s.end_with?("_REJECTED") }
        events.empty? ? [ results, nil ] : [ [], events ]
      rescue => ex
        Rails.logger.error("[RiskManager] risk evaluation failed — failing CLOSED: #{ex.class}: #{ex.message}")
        [ [], [ :RISK_EVALUATION_ERROR_REJECTED ] ]
      end
    end

    VALIDATORS = {
      vix_gate: VixGateValidator,
      margin: MarginValidator,
      max_drawdown: MaxDrawdownValidator,
      position_limit: PositionLimitValidator
    }.freeze
  end
end
