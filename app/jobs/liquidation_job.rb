# Force-closes a leveraged position that breached its liquidation price.
#
# Re-checks against the database (not the in-memory cache that enqueued it)
# before acting, since the cache can be a few seconds stale — the position
# may already have been closed, topped up, or liquidated by a previous
# enqueue of this same job by the time this one runs.
class LiquidationJob < ApplicationJob
  queue_as :risk

  discard_on ActiveRecord::RecordNotFound

  def perform(position_id, mark_price)
    position = ::PaperExchange::PaperPosition.find(position_id)
    return unless position.quantity.to_f != 0
    return unless position.liquidated?(mark_price)

    exchange = Exchange::PaperExchange.new(account_id: position.account_id)
    close_side = position.long? ? "sell" : "buy"

    order = exchange.submit_order(
      account_id: position.account_id,
      symbol: position.symbol,
      side: close_side,
      quantity: position.quantity.to_f.abs,
      order_kind: "market",
      instrument_type: position.instrument_type,
      option_type: position.option_type,
      strike_price: position.strike_price,
      expiry_date: position.expiry_date,
      ltp: mark_price,
      leverage: position.leverage,
      margin_type: position.margin_type,
      context: { reason: "LIQUIDATION" },
      internal: true,
      # reduce_only makes the close fill under a position row lock and clamp to
      # the live size, so a concurrent job or manual close can't flip the position.
      reduce_only: true
    )

    # Assert the outcome before declaring victory (audit M6): a close order
    # that never filled (matching error, empty book) used to still emit
    # POSITION_LIQUIDATED while the position stayed open — AND the enqueue
    # in LiquidationEngine.check_symbol! had already removed it from the
    # in-memory watch cache, so nothing re-checked it until the next push
    # happened to rebuild the cache. On a non-filled close: emit
    # LIQUIDATION_FAILED, cancel the orphan close order (internal orders
    # hold no locked margin), and refresh the cache so the position is
    # re-armed — the next mark-price push re-drives the liquidation.
    unless order&.status == "filled"
      order&.cancel! if order&.open?

      RiskEvent.create!(
        account_id: position.account_id,
        event_type: "LIQUIDATION_FAILED",
        details: {
          position_id: position.id,
          symbol: position.symbol,
          mark_price: mark_price.to_s,
          close_order_id: order&.id,
          order_status: order&.status,
          rejection_reason: order&.rejection_reason
        }
      )
      Risk::LiquidationEngine.refresh_cache!
      return
    end

    RiskEvent.create!(
      account_id: position.account_id,
      event_type: "POSITION_LIQUIDATED",
      details: {
        position_id: position.id,
        symbol: position.symbol,
        side: position.side,
        quantity: position.quantity.to_s,
        liquidation_price: position.liquidation_price.to_s,
        mark_price: mark_price.to_s,
        close_order_id: order&.id
      }
    )
  rescue Exchange::PaperExchange::PositionGoneError
    # Another close won the race; nothing left to liquidate, so it is not a failure.
    nil
  rescue => e
    RiskEvent.create!(
      account_id: position&.account_id || "UNKNOWN",
      event_type: "LIQUIDATION_FAILED",
      details: { position_id: position_id, mark_price: mark_price.to_s, error: e.message }
    )
    raise
  end
end
