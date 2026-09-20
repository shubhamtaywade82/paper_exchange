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
      context: { reason: "LIQUIDATION" }
    )

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
  rescue => e
    RiskEvent.create!(
      account_id: position&.account_id || "UNKNOWN",
      event_type: "LIQUIDATION_FAILED",
      details: { position_id: position_id, mark_price: mark_price.to_s, error: e.message }
    )
    raise
  end
end
