module Risk
  class RiskManager
    class << self
      def evaluate(account_id:, signal:)
        results = VALIDATORS.map do |name, validator|
          next [:passed, name] unless validator
          Array(validator.new.evaluate(account_id, signal))
        end.flatten(2)

        events = results.select { |r| r.is_a?(Symbol) && r.to_s.end_with?("_REJECTED") }
        if events.empty?
          results.last.is_a?(Hash) ? results : []
        else
          events.each do |event|
            RiskEvent.create!(account_id: account_id, event_type: event, details: { signal: signal.to_h })
          end
          []
        end
      rescue => ex
        RiskEvent.create!(account_id: account_id, event_type: "RISK_EVALUATION_ERROR", details: { error: ex.message, signal: signal.to_h })
        []
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
