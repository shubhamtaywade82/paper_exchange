# frozen_string_literal: true

class GetOptionChainTool < ApplicationMCPTool
  tool_name "get_option_chain"
  description "Option chain quotes, strikes, and Greeks (delta, gamma, theta, vega, IV, OI, volume). Read-only."

  property :underlying, type: "string", description: "Underlying symbol (e.g. BTC, NIFTY)"
  property :expiry_date, type: "string", description: "Filter by expiry date (YYYY-MM-DD)"
  property :limit, type: "integer", description: "Max option contracts to return (default: 30, max: 100)"

  def perform
    scope = ::OptionSnapshot.all
    scope = scope.where(underlying: underlying.upcase) if underlying.present?
    scope = scope.where(expiry_date: Date.parse(expiry_date)) if expiry_date.present? rescue scope

    max_records = limit.present? ? limit.to_i.clamp(1, 100) : 30
    snapshots = scope.order(snapshot_at: :desc, strike_price: :asc).limit(max_records).map do |o|
      {
        symbol: o.symbol,
        underlying: o.underlying,
        expiry_date: o.expiry_date.to_s,
        strike_price: o.strike_price.to_s,
        option_type: o.option_type,
        ltp: o.ltp&.to_s,
        bid: o.bid&.to_s,
        ask: o.ask&.to_s,
        iv: o.iv&.to_s,
        delta: o.delta&.to_s,
        gamma: o.gamma&.to_s,
        theta: o.theta&.to_s,
        vega: o.vega&.to_s,
        oi: o.oi,
        volume: o.volume,
        snapshot_at: o.snapshot_at.iso8601
      }
    end

    render_json(
      count: snapshots.size,
      options: snapshots
    )
  end
end
