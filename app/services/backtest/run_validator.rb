module Backtest
  # Validates a run definition at creation time, so a bad run is refused with
  # a 422 and never reaches the worker. Returns the attributes for
  # Backtest::Run.create!, with the strategy parameters normalized.
  module RunValidator
    class Invalid < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = Array(errors)
        super(@errors.first(20).join("; "))
      end
    end

    SCHEMA = Dry::Schema.Params do
      required(:dataset_id).filled(:integer)
      required(:name).filled(:string, max_size?: 120)
      required(:strategy).hash do
        required(:key).filled(:string)
        optional(:params).maybe(:hash)
      end
      required(:sizing).hash do
        required(:type).filled(:string, included_in?: %w[fixed percent_of_equity risk_percent])
        optional(:quantity).maybe(:decimal, gt?: 0)
        optional(:percent).maybe(:decimal, gt?: 0, lteq?: 100)
        optional(:risk_percent).maybe(:decimal, gt?: 0, lteq?: 100)
      end
      optional(:initial_capital).maybe(:decimal, gt?: 0)
      optional(:leverage).maybe(:integer, gteq?: 1, lteq?: 100)
      optional(:slippage_bps).maybe(:decimal, gteq?: 0, lt?: 1000)
      optional(:lot_size).maybe(:decimal, gt?: 0)
      optional(:risk_gate).maybe(:bool)
    end

    module_function

    def call(payload)
      result = SCHEMA.call(payload.to_h.deep_symbolize_keys)
      raise Invalid, result.errors.to_h.map { |field, msgs| "#{field}: #{Array(msgs).join(', ')}" } unless result.errors.empty?

      values = result.to_h
      dataset = Dataset.find_by(id: values[:dataset_id])
      raise Invalid, "dataset_id #{values[:dataset_id]} does not exist" unless dataset

      contract = Contract.from_dataset(dataset)
      lot_size = values[:lot_size] || BigDecimal("1")
      leverage = values[:leverage] || 1
      raise Invalid, "leverage above 1 is only supported for CRYPTO_PERPETUAL, not #{contract.instrument_type}" if leverage > 1 && !contract.leverage_allowed?

      sizing = normalize_sizing(values[:sizing], lot_size)
      strategy_params = begin
        Strategies.normalize(values[:strategy][:key], values[:strategy][:params], contract: contract, lot_size: lot_size)
      rescue Strategies::InvalidParams => e
        raise Invalid, "strategy: #{e.message}"
      end

      {
        name: values[:name].strip,
        backtest_dataset_id: dataset.id,
        strategy_key: values[:strategy][:key].to_s,
        strategy_params: strategy_params,
        initial_capital: values[:initial_capital] || Parse.decimal(ENV.fetch("PAPER_EXCHANGE_MARGIN", "10000")),
        leverage: leverage,
        sizing: sizing,
        slippage_bps: values[:slippage_bps] || BigDecimal("0"),
        lot_size: lot_size,
        risk_gate: values.key?(:risk_gate) && !values[:risk_gate].nil? ? values[:risk_gate] : true
      }
    end

    def normalize_sizing(sizing, lot_size)
      case sizing[:type]
      when "fixed"
        quantity = sizing[:quantity]
        raise Invalid, "sizing.quantity is required for fixed sizing" if quantity.nil?
        raise Invalid, "sizing.quantity must be a multiple of lot_size #{lot_size.to_s('F')}" unless IntentValidator.lot_multiple?(quantity, lot_size)

        { "type" => "fixed", "quantity" => quantity.to_s("F") }
      when "percent_of_equity"
        percent = sizing[:percent]
        raise Invalid, "sizing.percent is required for percent_of_equity sizing" if percent.nil?

        { "type" => "percent_of_equity", "percent" => percent.to_s("F") }
      when "risk_percent"
        # Position size such that a stop-out loses this share of equity.
        risk = sizing[:risk_percent]
        raise Invalid, "sizing.risk_percent is required for risk_percent sizing" if risk.nil?

        { "type" => "risk_percent", "risk_percent" => risk.to_s("F") }
      end
    end
  end
end
