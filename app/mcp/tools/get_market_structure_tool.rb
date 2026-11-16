# frozen_string_literal: true

class GetMarketStructureTool < ApplicationMCPTool
  tool_name "get_market_structure"
  description "Smart Money Concepts (SMC) market structure: trend, premium/discount, order blocks, FVG counts, BOS, and CHoCH. Read-only."

  property :symbol, type: "string", description: "Symbol to inspect (e.g. BTCUSDT, NIFTY)"
  property :timeframe, type: "string", description: "Timeframe (e.g. 5m, 15m, 1h; default: 5m)"

  def perform
    scope = ::MarketStructureSnapshot.all
    scope = scope.where(symbol: symbol.upcase) if symbol.present?
    scope = scope.where(timeframe: timeframe) if timeframe.present?

    snapshots = scope.order(as_of: :desc).limit(10).map do |s|
      {
        symbol: s.symbol,
        timeframe: s.timeframe,
        trend: s.trend,
        premium_discount: s.premium_discount,
        order_block: s.order_block,
        liquidity_sweep: s.liquidity_sweep,
        last_bos: s.last_bos,
        last_choch: s.last_choch,
        bullish_fvg_count: s.bullish_fvg_count,
        bearish_fvg_count: s.bearish_fvg_count,
        as_of: s.as_of.iso8601
      }
    end

    render_json(
      count: snapshots.size,
      snapshots: snapshots
    )
  end
end
