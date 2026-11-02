module Backtest
  # Validates a run definition at creation time, so a bad run is refused with
  # a 422 and never reaches a worker or a bot. Returns the attributes for
  # Backtest::Run.create!, with the strategy parameters normalized.
  #
  # mode "engine"   needs a built-in strategy and sizing
  # mode "external" is driven over the API: the bot sends quantities, so no
  #                 strategy or sizing is accepted
  module RunValidator
    class Invalid < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = Array(errors)
        super(@errors.first(20).join("; "))
      end
    end

    MANIFEST_MAX_BYTES = 16_000
    BENCHMARK_KEYS = %w[
      min_trades min_profit_factor max_drawdown_pct min_net_profit_pct
      min_percent_profitable min_sharpe_ratio beat_buy_and_hold
    ].freeze

    SCHEMA = Dry::Schema.Params do
      required(:dataset_id).filled(:integer)
      required(:name).filled(:string, max_size?: 120)
      optional(:mode).maybe(:string, included_in?: Run::MODES)
      optional(:strategy).maybe(:hash) do
        required(:key).filled(:string)
        optional(:params).maybe(:hash)
      end
      optional(:sizing).maybe(:hash) do
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
      optional(:benchmarks).maybe(:hash)
      optional(:manifest).maybe(:hash)
    end

    module_function

    def call(payload)
      result = SCHEMA.call(payload.to_h.deep_symbolize_keys)
      unless result.errors.empty?
        raise Invalid, result.errors.to_h.map { |field, msgs| "#{field}: #{Array(msgs).join(', ')}" }
      end

      values = result.to_h
      dataset = Dataset.find_by(id: values[:dataset_id])
      raise Invalid, "dataset_id #{values[:dataset_id]} does not exist" unless dataset

      mode = (values[:mode] || (values[:strategy] ? "engine" : "external"))
      contract = Contract.from_dataset(dataset)
      lot_size = values[:lot_size] || BigDecimal("1")
      leverage = values[:leverage] || 1
      if leverage > 1 && !contract.leverage_allowed?
        raise Invalid, "leverage above 1 is only supported for CRYPTO_PERPETUAL, not #{contract.instrument_type}"
      end

      strategy_key, strategy_params, sizing = mode == "engine" ? engine_definition(values, contract, lot_size) : external_definition(values)

      {
        name: values[:name].strip,
        mode: mode,
        backtest_dataset_id: dataset.id,
        strategy_key: strategy_key,
        strategy_params: strategy_params,
        initial_capital: values[:initial_capital] || Parse.decimal(ENV.fetch("PAPER_EXCHANGE_MARGIN", "10000")),
        leverage: leverage,
        sizing: sizing,
        slippage_bps: values[:slippage_bps] || BigDecimal("0"),
        lot_size: lot_size,
        risk_gate: values[:risk_gate].nil? ? true : values[:risk_gate],
        benchmarks: normalize_benchmarks(values[:benchmarks]),
        manifest: normalize_manifest(values[:manifest])
      }
    end

    def engine_definition(values, contract, lot_size)
      raise Invalid, "mode engine needs a strategy" unless values[:strategy]
      raise Invalid, "mode engine needs sizing" unless values[:sizing]

      params = begin
        Strategies.normalize(values[:strategy][:key], values[:strategy][:params], contract: contract, lot_size: lot_size)
      rescue Strategies::InvalidParams => e
        raise Invalid, "strategy: #{e.message}"
      end
      [ values[:strategy][:key].to_s, params, normalize_sizing(values[:sizing], lot_size) ]
    end

    def external_definition(values)
      if values[:strategy]
        raise Invalid, "mode external takes no strategy: the bot decides over the API. Remove strategy, or use mode engine"
      end

      [ "external", {}, {} ]
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

    # Benchmarks are thresholds the caller chose. Each one is evaluated on the
    # finished run (see Backtest::Verdict). Nothing is assumed when none are given.
    def normalize_benchmarks(raw)
      return {} if raw.blank?

      errors = []
      raw.to_h.stringify_keys.each do |key, value|
        unless BENCHMARK_KEYS.include?(key)
          errors << "benchmarks.#{key} is not a known benchmark (#{BENCHMARK_KEYS.join(', ')})"
          next
        end

        if key == "beat_buy_and_hold"
          errors << "benchmarks.beat_buy_and_hold must be true or false" unless [ true, false ].include?(value)
        elsif Parse.decimal(value).nil?
          errors << "benchmarks.#{key} must be a finite number"
        end
      end
      raise Invalid, errors if errors.any?

      raw.to_h.stringify_keys.to_h do |key, value|
        [ key, key == "beat_buy_and_hold" ? value : Parse.decimal(value).to_s("F") ]
      end
    end

    # The manifest says what was tested: strategy name and version, parameters,
    # notes. The engine stores it verbatim and never reads it.
    def normalize_manifest(raw)
      return {} if raw.blank?

      size = raw.to_h.to_json.bytesize
      raise Invalid, "manifest is #{size} bytes; the limit is #{MANIFEST_MAX_BYTES}" if size > MANIFEST_MAX_BYTES

      raw.to_h.deep_stringify_keys
    end
  end
end
