module Charges
  # The India charge rules that Exchange::BrokerageCalculator computed from ENV
  # defaults and constants before rule rows existed. Installing them keeps every
  # charge unchanged, and makes each value a row with a source.
  #
  # The values are NOT verified against current circulars. Verifying them, and
  # supplying the effective-dated schedule, is a required input (MULTI_MARKET_SPEC
  # §14, item 2). Installation reads ENV once, at install time, so an operator's
  # pinned override is carried into the row.
  #
  # Install: bin/rails charges:install_legacy_rules (idempotent). The test suite
  # installs the same rows before each example.
  module LegacyRules
    SOURCE = "legacy: Exchange::BrokerageCalculator ENV defaults at install; unverified against circulars".freeze
    EFFECTIVE_FROM = Date.new(2026, 4, 1)
    BROKERAGE_RATE = BigDecimal("0.0003")
    PRODUCTS = %w[EQUITY_CASH FUTURES OPTIONS].freeze

    module_function

    def install!
      rows.each do |attrs|
        key = attrs.slice(:product, :component, :side, :effective_from)
        ChargeRule.find_or_create_by!(key) { |rule| rule.assign_attributes(attrs.except(*key.keys)) }
      end
    end

    def rows
      floor = env("PAPER_EXCHANGE_BROKERAGE_FLOOR", "20.0")
      sebi = env("PAPER_EXCHANGE_SEBI_FEE", "0.0001")
      txn = env("PAPER_EXCHANGE_EXCHANGE_TXN", "0.00145", percent: true)
      stamp = env("PAPER_EXCHANGE_STAMP_DUTY", "0.003", percent: true)
      gst = env("PAPER_EXCHANGE_GST", "18", percent: true)
      stt = {
        "EQUITY_CASH" => [
          [ "buy", env("PAPER_EXCHANGE_STT_DELIVERY", "0.025", percent: true) ],
          [ "sell", env("PAPER_EXCHANGE_STT_INTRADAY", "0.0125", percent: true) ]
        ],
        "FUTURES" => [ [ "sell", env("PAPER_EXCHANGE_STT_FUTURES_SELL", "0.05", percent: true) ] ],
        "OPTIONS" => [ [ "sell", env("PAPER_EXCHANGE_STT_OPTIONS_SELL", "0.15", percent: true) ] ]
      }

      PRODUCTS.flat_map do |product|
        [
          row(product, "brokerage", "both", "turnover", rate: BROKERAGE_RATE, minimum: floor),
          row(product, "sebi", "both", "turnover", rate: sebi),
          row(product, "exchange_txn", "both", "turnover", rate: txn),
          row(product, "stamp_duty", "buy", "turnover", rate: stamp),
          row(product, "gst", "both", "component_sum", rate: gst, base: %w[brokerage sebi exchange_txn])
        ] + stt.fetch(product).map { |side, rate| row(product, "stt", side, "turnover", rate: rate) }
      end
    end

    def row(product, component, side, basis, rate:, minimum: nil, base: nil)
      {
        product: product, component: component, side: side, basis: basis,
        rate: rate, flat_amount: nil, minimum_amount: minimum, maximum_amount: nil,
        rounding_scale: 2, base_components: base, effective_from: EFFECTIVE_FROM,
        effective_until: nil, source_ref: SOURCE
      }
    end

    def env(name, default, percent: false)
      value = BigDecimal(ENV.fetch(name, default))
      percent ? value / 100 : value
    end
  end
end
