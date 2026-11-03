module Charges
  # India trade charges, computed from ChargeRule rows in force on the trade's
  # exchange-local date (MULTI_MARKET_SPEC §9).
  #
  # Every amount is BigDecimal. A missing rule for a component raises MissingRule;
  # there is no default rate. A component that is not charged on this side has
  # no matching row, and contributes zero. Ambiguity, two rows matching one side,
  # raises AmbiguousRule.
  class Calculator
    class MissingRule < StandardError; end
    class AmbiguousRule < StandardError; end

    ZONE = "Asia/Kolkata".freeze

    # Products are the unit of charging, not the segment name. An instrument type
    # with no product here has no rules, and is refused until its rules are loaded.
    PRODUCT_FOR = {
      "EQUITY" => "EQUITY_CASH",
      "FUTIDX" => "FUTURES",
      "FUTSTK" => "FUTURES",
      "OPTIDX" => "OPTIONS",
      "OPTSTK" => "OPTIONS"
    }.freeze

    # Components charged from turnover, in order. GST is a component_sum over
    # some of them, so it is computed last.
    BASE_COMPONENTS = %w[brokerage stt sebi exchange_txn stamp_duty].freeze

    def calculate(trade_price:, quantity:, side:, instrument_type:, at: Clock.now)
      product = PRODUCT_FOR.fetch(instrument_type) do
        raise MissingRule, "no charge rules for #{instrument_type}; it is refused until its rules are loaded"
      end
      trade_date = Clock.exchange_date(zone: ZONE, at: at)
      rules = ChargeRule.in_force_on(trade_date).where(product: product, exchange_id: nil).to_a

      turnover = BigDecimal(trade_price.to_s) * BigDecimal(quantity.to_s)
      amounts = {}
      scales = {}
      rule_ids = []

      BASE_COMPONENTS.each do |component|
        record(amounts, scales, rule_ids, component, select_rule(rules, component, side, product, trade_date)) do |rule|
          rule ? amount(rule, turnover) : BigDecimal("0")
        end
      end

      gst_rule = select_rule(rules, "gst", side, product, trade_date)
      record(amounts, scales, rule_ids, "gst", gst_rule) do |rule|
        next BigDecimal("0") unless rule

        base = rule.base_components.sum(BigDecimal("0")) { |component| amounts.fetch(component) }
        base * rule.rate
      end

      # A component with no rule is zero, which rounds to zero at any scale; 2 is
      # only the presentation scale for it. The total is the unrounded sum, rounded
      # to the largest component scale, as the calculator has always done.
      total = amounts.values.sum(BigDecimal("0"))
      total_scale = scales.values.max || 2
      rounded = amounts.to_h { |component, value| [ component.to_sym, value.round(scales.fetch(component, 2)) ] }

      rounded.merge(total: total.round(total_scale), notional: turnover.round(2), rule_ids: rule_ids)
    end

    private

    def record(amounts, scales, rule_ids, component, rule)
      amounts[component] = yield(rule)
      return unless rule

      scales[component] = rule.rounding_scale
      rule_ids << rule.id
    end

    # Exactly one row for the side, or nil when this component is not charged on
    # this side. No rows at all for the component is a missing rule, not a zero.
    def select_rule(rules, component, side, product, trade_date)
      candidates = rules.select { |rule| rule.component == component }
      raise MissingRule, "no #{component} charge rule for #{product} on #{trade_date}" if candidates.empty?

      matching = candidates.select { |rule| rule.side == side || rule.side == "both" }
      raise AmbiguousRule, "more than one #{component} rule for #{product} #{side} on #{trade_date}" if matching.size > 1

      matching.first
    end

    def amount(rule, turnover)
      case rule.basis
      when "turnover"
        value = turnover * rule.rate
        value = [ value, rule.minimum_amount ].max if rule.minimum_amount
        value = [ value, rule.maximum_amount ].min if rule.maximum_amount
        value
      when "flat"
        rule.flat_amount
      else
        raise ArgumentError, "charge basis #{rule.basis} is not computed here"
      end
    end
  end
end
