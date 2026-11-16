# frozen_string_literal: true

class GetClosedPositionsTool < ApplicationMCPTool
  tool_name "get_closed_positions"
  description "Fetch recent closed trades and realized PnL history for an account"

  property :account_id, type: "string", description: "Account identifier to inspect (default: test-account-1)"
  property :limit, type: "integer", description: "Maximum number of recent trades to return (default: 20)"

  def perform
    acc_id = account_id.presence || "test-account-1"
    account = Account.find_by(account_id: acc_id)
    return render_json(error: "account_not_found", account_id: acc_id) unless account

    max_records = limit.present? ? [limit.to_i, 100].min : 20
    trades = ::PaperExchange::PaperTrade
      .joins(:paper_order)
      .where(paper_exchange_orders: { account_id: acc_id })
      .order(traded_at: :desc)
      .limit(max_records)
      .map do |t|
        {
          id: t.id,
          order_id: t.paper_order_id,
          symbol: t.paper_order.symbol,
          side: t.paper_order.side,
          quantity: t.quantity.to_s,
          price: t.price.to_s,
          total_charges: t.total_charges.to_s,
          traded_at: t.traded_at&.iso8601
        }
      end

    render_json(
      account_id: acc_id,
      count: trades.size,
      trades: trades
    )
  end
end
