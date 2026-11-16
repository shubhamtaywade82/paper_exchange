# frozen_string_literal: true

class GetPositionDetailsTool < ApplicationMCPTool
  tool_name "get_position_details"
  description "Full detail for one open or closed position: entry price, mark price, leverage, initial margin, " \
              "liquidation price, unrealized PnL, and attached protections (SL/TP/trailing). Read-only."

  property :position_id, type: "integer", description: "Position row ID"
  property :symbol, type: "string", description: "Symbol to look up if position_id is omitted (e.g. BTCUSDT)"
  property :account_id, type: "string", description: "Account identifier (default: test-account-1)"

  def perform
    acc_id = account_id.presence || "test-account-1"
    scope = ::PaperExchange::PaperPosition.where(account_id: acc_id)
    position =
      if position_id.present?
        scope.find_by(id: position_id)
      elsif symbol.present?
        scope.where(symbol: symbol.upcase).order(updated_at: :desc).first
      else
        scope.order(updated_at: :desc).first
      end

    return render_json(error: "position_not_found", account_id: acc_id) unless position

    protections = ::PositionProtection.where(paper_position_id: position.id).map do |p|
      {
        id: p.id,
        protection_type: p.protection_type,
        trigger_price: p.trigger_price&.to_s,
        trailing_distance: p.trailing_distance&.to_s,
        quantity: p.quantity&.to_s,
        status: p.status,
        high_water_mark: p.high_water_mark&.to_s,
        low_water_mark: p.low_water_mark&.to_s
      }
    end

    render_json(
      id: position.id,
      account_id: position.account_id,
      symbol: position.symbol,
      side: position.side,
      quantity: position.quantity.to_s,
      avg_price: position.avg_price&.to_s,
      current_price: position.current_price&.to_s,
      leverage: position.leverage,
      margin_type: position.margin_type,
      initial_margin: position.initial_margin.to_s,
      liquidation_price: position.liquidation_price&.to_s,
      unrealized_pnl: position.unrealized_pnl&.to_s,
      protections: protections,
      updated_at: position.updated_at&.iso8601
    )
  end
end
