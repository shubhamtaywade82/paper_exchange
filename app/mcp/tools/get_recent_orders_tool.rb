# frozen_string_literal: true

class GetRecentOrdersTool < ApplicationMCPTool
  tool_name "get_recent_orders"
  description "Recent paper orders placed on the exchange, including status, kind, quantity, price, and fills. Read-only."

  property :account_id, type: "string", description: "Account identifier (default: test-account-1)"
  property :symbol, type: "string", description: "Filter by symbol (e.g. BTCUSDT)"
  property :status, type: "string", description: "Filter by order status (pending, open, filled, cancelled, rejected)"
  property :limit, type: "integer", description: "Max orders to return (default 20, max 100)"

  def perform
    acc_id = account_id.presence || "test-account-1"
    scope = ::PaperExchange::PaperOrder.where(account_id: acc_id)
    scope = scope.where(symbol: symbol.upcase) if symbol.present?
    scope = scope.where(status: status) if status.present?

    max_records = limit.present? ? limit.to_i.clamp(1, 100) : 20
    orders = scope.order(placed_at: :desc).limit(max_records).map do |o|
      {
        id: o.id,
        account_id: o.account_id,
        symbol: o.symbol,
        side: o.side,
        order_kind: o.order_kind,
        quantity: o.quantity.to_s,
        price: o.price&.to_s,
        trigger_price: o.trigger_price&.to_s,
        status: o.status,
        filled_quantity: o.filled_quantity.to_s,
        locked_margin: o.locked_margin.to_s,
        leverage: o.leverage,
        placed_at: o.placed_at.iso8601,
        rejection_reason: o.rejection_reason
      }
    end

    render_json(
      account_id: acc_id,
      count: orders.size,
      orders: orders
    )
  end
end
