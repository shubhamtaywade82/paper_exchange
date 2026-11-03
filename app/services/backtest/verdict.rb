module Backtest
  # Pass/fail judgment of a finished run against the benchmarks its caller
  # declared. The thresholds are the caller's; none are assumed here. A run
  # with no declared benchmarks gets passed = nil, not a silent pass.
  #
  #   min_trades              total_trades >= x
  #   min_profit_factor       profit_factor >= x
  #   max_drawdown_pct        max_drawdown_pct <= x
  #   min_net_profit_pct      net_profit_pct >= x
  #   min_percent_profitable  percent_profitable >= x
  #   min_sharpe_ratio        sharpe_ratio >= x
  #   beat_buy_and_hold       true: equity_change_pct > buy_and_hold_return_pct
  module Verdict
    NUMERIC = {
      "min_trades" => [ "total_trades", :>= ],
      "min_profit_factor" => [ "profit_factor", :>= ],
      "max_drawdown_pct" => [ "max_drawdown_pct", :<= ],
      "min_net_profit_pct" => [ "net_profit_pct", :>= ],
      "min_percent_profitable" => [ "percent_profitable", :>= ],
      "min_sharpe_ratio" => [ "sharpe_ratio", :>= ]
    }.freeze
    KEYS = (NUMERIC.keys + [ "beat_buy_and_hold" ]).freeze

    module_function

    def call(benchmarks:, metrics:)
      declared = benchmarks.to_h.stringify_keys.slice(*KEYS)
      declared = declared.select { |name, value| name != "beat_buy_and_hold" || value == true }
      return { "passed" => nil, "checks" => [], "note" => "no benchmarks declared" } if declared.empty?

      metrics = metrics.to_h.stringify_keys
      checks = declared.map { |name, required| check(name, required, metrics) }
      { "passed" => checks.all? { |c| c["passed"] }, "checks" => checks }
    end

    def check(name, required, metrics)
      if name == "beat_buy_and_hold"
        actual = metrics["equity_change_pct"]
        benchmark = metrics["buy_and_hold_return_pct"]
        passed = !actual.nil? && !benchmark.nil? && actual > benchmark
        return { "check" => name, "required" => true, "actual" => actual, "benchmark" => benchmark, "passed" => passed }
      end

      metric, operator = NUMERIC.fetch(name)
      actual = metrics[metric]
      threshold = required.to_f
      passed = !actual.nil? && actual.to_f.public_send(operator, threshold)
      { "check" => name, "metric" => metric, "required" => threshold, "actual" => actual, "passed" => passed }
    end
  end
end
