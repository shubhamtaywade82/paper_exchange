# Architecture alignment (target architecture §5): durable position protection
# policies. Stored at order acceptance or position creation so stop-loss,
# take-profit, trailing stops, and OCO behavior survive process restarts.
#
# A protection is linked to a PaperPosition. When the position is partially
# closed, the protection's quantity should be updated; when the position goes
# flat, the protection is cancelled. The ProtectionMonitor job checks each
# active protection against the latest mark price from QuoteStore and triggers
# a force-close order when the breach condition is met.
#
# Protection types:
#   stop_loss      — triggers when price breaches trigger_price against the
#                    position (long: price <= trigger; short: price >= trigger).
#                    Fills as a market order (stop-market semantics).
#   take_profit    — triggers when price reaches trigger_price in the position's
#                    favor (long: price >= trigger; short: price <= trigger).
#   trailing_stop  — a stop-loss that trails the high-water mark (long) or
#                    low-water mark (short) by trailing_distance. The trigger
#                    price is recomputed on every mark-price update.
#
# OCO (one-cancels-other): link two protections (e.g. SL + TP) with the same
# oco_group_id. When one triggers, the other is cancelled atomically.
class PositionProtection < ApplicationRecord
  self.table_name = "position_protections"

  PROTECTION_TYPES = %w[stop_loss take_profit trailing_stop].freeze
  STATUSES = %w[active triggered cancelled expired].freeze

  belongs_to :paper_position, class_name: "PaperExchange::PaperPosition"

  validates :protection_type, presence: true, inclusion: { in: PROTECTION_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quantity, numericality: { greater_than: 0 }
  validates :trigger_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :trailing_distance, numericality: { greater_than: 0 }, allow_nil: true
  validate :required_price_for_type

  # Checks whether this protection should trigger at the given mark price.
  # Returns true if the breach condition is met. Does NOT perform the close —
  # the caller (ProtectionMonitor) is responsible for creating the close order.
  def breached?(mark_price)
    return false unless active?
    return false if mark_price.nil? || mark_price <= 0

    case protection_type
    when "stop_loss"
      stop_loss_breached?(mark_price)
    when "take_profit"
      take_profit_breached?(mark_price)
    when "trailing_stop"
      trailing_stop_breached?(mark_price)
    else
      false
    end
  end

  def active?
    status == "active"
  end

  # Updates the trailing stop's high/low water mark based on the current
  # price. Called by the ProtectionMonitor on every mark-price push for
  # trailing_stop protections. Returns the updated trigger price (or nil
  # if the protection is not a trailing stop).
  def update_water_mark!(mark_price)
    return nil unless protection_type == "trailing_stop" && active?
    return nil if mark_price.nil?

    position = paper_position
    if position.long?
      current_hwm = high_water_mark || position.avg_price.to_f
      new_hwm = [ current_hwm.to_f, mark_price.to_f ].max
      update_columns(
        high_water_mark: new_hwm,
        trigger_price: new_hwm - trailing_distance.to_f
      )
    else
      current_lwm = low_water_mark || position.avg_price.to_f
      new_lwm = [ current_lwm.to_f, mark_price.to_f ].min
      update_columns(
        low_water_mark: new_lwm,
        trigger_price: new_lwm + trailing_distance.to_f
      )
    end
    trigger_price
  end

  # Marks this protection as triggered and cancels any OCO siblings.
  def trigger!
    transaction do
      update_columns(status: "triggered", triggered_at: Time.current)
      cancel_oco_siblings! if oco_group_id.present?
    end
  end

  def cancel!
    update_columns(status: "cancelled", cancelled_at: Time.current)
  end

  private

  def stop_loss_breached?(mark_price)
    position = paper_position
    return false unless trigger_price
    position.long? ? mark_price <= trigger_price.to_f : mark_price >= trigger_price.to_f
  end

  def take_profit_breached?(mark_price)
    position = paper_position
    return false unless trigger_price
    position.long? ? mark_price >= trigger_price.to_f : mark_price <= trigger_price.to_f
  end

  def trailing_stop_breached?(mark_price)
    # After update_water_mark! has set trigger_price, the breach check
    # is the same as a stop_loss.
    return false unless trigger_price
    stop_loss_breached?(mark_price)
  end

  def cancel_oco_siblings!
    return unless oco_group_id
    PositionProtection
      .where(oco_group_id: oco_group_id, status: "active")
      .where.not(id: id)
      .update_all(status: "cancelled", cancelled_at: Time.current)
  end

  def required_price_for_type
    case protection_type
    when "stop_loss", "take_profit"
      errors.add(:trigger_price, "is required for #{protection_type}") if trigger_price.nil?
    when "trailing_stop"
      errors.add(:trailing_distance, "is required for trailing_stop") if trailing_distance.nil?
    end
  end
end
