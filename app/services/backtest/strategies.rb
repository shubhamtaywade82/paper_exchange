module Backtest
  # Strategy registry. Each entry is a class that knows its key, its parameter
  # schema, and how to decide on each bar. Adding a strategy means adding a
  # class here and a row to REGISTRY.
  module Strategies
    REGISTRY = [ SmaCross, SignalReplay ].freeze

    module_function

    def keys
      REGISTRY.map(&:key)
    end

    def fetch(key)
      REGISTRY.find { |strategy| strategy.key == key.to_s } ||
        raise(InvalidParams, "unknown strategy #{key.inspect}; known strategies: #{keys.join(', ')}")
    end

    def normalize(key, raw_params, contract:, lot_size:)
      fetch(key).normalize_params(raw_params || {}, contract: contract, lot_size: lot_size)
    end

    def build(key, params, contract:)
      fetch(key).new(params, contract: contract)
    end
  end
end
