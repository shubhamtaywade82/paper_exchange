module Risk
  class VixGate
    MAX_VIX = 20.0

    def self.allowed?(vix)
      !vix.nil? && vix <= MAX_VIX
    end
  end
end
