# Architecture alignment (target architecture §5): autonomous position
# protection. This job scans all active PositionProtection records, updates
# trailing-stop water marks from the latest mark price, and triggers
# force-close orders when a protection's breach condition is met.
#
# The job is designed to run as a recurring Solid Queue task (every few
# seconds) or as a dedicated long-lived consumer that reads mark-price
# events from the Redis tick stream. It does NOT depend on the trading
# bot — protections are durable in PostgreSQL and survive restarts.
#
# When a protection triggers, it creates a reduce_only market order via
# PaperExchange#submit_order (the same path LiquidationJob uses), so the
# close is transactional, idempotent via the order's status guard, and
# posts realized PnL + fees through the normal accounting path.
class ProtectionMonitorJob < ApplicationJob
  queue_as :risk

  def perform
    ::PositionProtection.where(status: "active").find_each do |protection|
      evaluate_protection(protection)
    end
  end

  private

  def evaluate_protection(protection)
    position = protection.paper_position
    return if position.nil? || position.quantity.to_f.zero?

    # Fetch the latest mark price from QuoteStore (venue-aware). Falls back
    # to the legacy MarkPriceStore for paper-venue positions.
    mark_price = fetch_mark_price(protection)
    return if mark_price.nil?

    # Update trailing-stop water marks before checking the breach.
    protection.update_water_mark!(mark_price) if protection.protection_type == "trailing_stop"

    return unless protection.breached?(mark_price)

    trigger_close(protection, position, mark_price)
  rescue StandardError => e
    Rails.logger.error("[ProtectionMonitor] error evaluating protection #{protection.id}: #{e.class}: #{e.message}")
  end

  def fetch_mark_price(protection)
    quote = MarketData::QuoteStore.get(protection.venue, protection.instrument_id)
    return quote[:mark_price] || quote[:ltp] if quote && !MarketData::QuoteStore.stale?(quote)

    # Fallback for paper-venue or when QuoteStore has no entry.
    MarketData::MarkPriceStore.get(protection.instrument_id) || position(protection).current_price.to_f
  end

  def position(protection)
    protection.paper_position
  end

  # Triggers a force-close order for the protection's quantity. Uses the
  # same internal/reduce_only path as LiquidationJob so the close bypasses
  # the margin lock (the position is by definition at risk) and runs
  # through the normal fill + ledger sequence.
  def trigger_close(protection, position, mark_price)
    exchange = Exchange::PaperExchange.new(account_id: protection.account_id)
    close_side = position.long? ? "sell" : "buy"

    exchange.submit_order(
      account_id: protection.account_id,
      symbol: position.symbol,
      side: close_side,
      quantity: [ protection.quantity.to_f, position.quantity.to_f ].min,
      order_kind: "market",
      instrument_type: position.instrument_type,
      option_type: position.option_type,
      strike_price: position.strike_price,
      expiry_date: position.expiry_date,
      ltp: mark_price,
      leverage: position.leverage,
      margin_type: position.margin_type,
      context: { reason: "PROTECTION_TRIGGER", protection_id: protection.id },
      internal: true,
      reduce_only: true,
      client_order_id: "protection-#{protection.id}"
    )

    protection.trigger!
    RiskEvent.create!(
      account_id: protection.account_id,
      event_type: "PROTECTION_TRIGGERED",
      details: {
        protection_id: protection.id,
        position_id: position.id,
        symbol: position.symbol,
        protection_type: protection.protection_type,
        trigger_price: protection.trigger_price.to_s,
        mark_price: mark_price.to_s
      }
    )
  rescue Exchange::PaperExchange::PositionGoneError
    # The position was already closed (by a manual close or another
    # protection). Cancel the protection — there is nothing to protect.
    protection.cancel!
  rescue ::PaperExchange::PaperOrder::StateError
    # The protection close order already exists (idempotent client_order_id).
    # Mark the protection as triggered so we don't keep retrying.
    protection.trigger!
  end
end
