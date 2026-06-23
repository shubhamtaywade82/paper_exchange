module Risk
  class VixGateValidator
    def initialize(max_vix: 20.0)
      @max_vix = max_vix
    end

    def evaluate(account_id, signal)
      vix = signal.to_h.dig(:context, :vix)
      return :passed unless vix

      vix <= @max_vix ? :passed : :VIX_REJECTED
    end
  end
end
