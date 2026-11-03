# One effective-dated charge component for one product (MULTI_MARKET_SPEC §9).
# The exclusion constraint in the database guarantees at most one row per
# (product, component, side, exchange, date). A missing rule is never defaulted.
class ChargeRule < ApplicationRecord
  PRODUCTS = %w[EQUITY_CASH FUTURES OPTIONS].freeze
  COMPONENTS = %w[brokerage stt exchange_txn sebi stamp_duty gst].freeze
  SIDES = %w[buy sell both].freeze
  BASES = %w[turnover flat component_sum].freeze

  belongs_to :exchange, class_name: "Markets::Exchange", optional: true

  validates :product, inclusion: { in: PRODUCTS }
  validates :component, inclusion: { in: COMPONENTS }
  validates :side, inclusion: { in: SIDES }
  validates :basis, inclusion: { in: BASES }
  validates :effective_from, :source_ref, :rounding_scale, presence: true
  validates :rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :flat_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :exactly_one_amount_source
  validate :base_components_for_component_sum
  validate :effective_window_ordered

  scope :in_force_on, lambda { |date|
    where("effective_from <= ? AND (effective_until IS NULL OR effective_until >= ?)", date, date)
  }

  private

  def exactly_one_amount_source
    return if basis == "component_sum"
    return if rate.nil? ^ flat_amount.nil?

    errors.add(:base, "needs exactly one of rate or flat_amount")
  end

  def base_components_for_component_sum
    return unless basis == "component_sum"
    return if base_components.is_a?(Array) && base_components.any?

    errors.add(:base_components, "must list the components the rate applies to")
  end

  def effective_window_ordered
    return if effective_until.nil? || effective_from.nil? || effective_until >= effective_from

    errors.add(:effective_until, "must not be before effective_from")
  end
end
