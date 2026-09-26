module Strategy
  # Market-structure snapshots (smart-money-concepts context: trend,
  # break-of-structure / change-of-character flags, fair-value-gap
  # counts, liquidity sweep / order block / premium-discount tags) per
  # symbol + timeframe.
  #
  # DB-backed (market_structure_snapshots), not in-memory: snapshots
  # must survive restarts and be visible to every process — POST
  # /api/market_structure writes here and the strategy read path
  # (POST /api/strategy/signals context, GET /api/market_structure)
  # reads the newest row per (symbol, timeframe).
  class MarketStructureEngine
    def ingest(symbol, timeframe: "5m", trend: nil, bos: false, choch: false,
               bullish_fvg_count: 0, bearish_fvg_count: 0,
               liquidity_sweep: nil, order_block: nil, premium_discount: nil,
               as_of: Time.current)
      MarketStructureSnapshot.create!(
        symbol: symbol.to_s.upcase,
        timeframe: timeframe.to_s,
        trend: trend,
        last_bos: bos,
        last_choch: choch,
        bullish_fvg_count: bullish_fvg_count,
        bearish_fvg_count: bearish_fvg_count,
        liquidity_sweep: liquidity_sweep,
        order_block: order_block,
        premium_discount: premium_discount,
        as_of: as_of
      )
    end

    def snapshot(symbol, timeframe: "5m")
      MarketStructureSnapshot
        .where(symbol: symbol.to_s.upcase, timeframe: timeframe.to_s)
        .order(as_of: :desc, id: :desc)
        .first
    end

    def latest(timeframe: "5m")
      MarketStructureSnapshot.latest_per_symbol(timeframe: timeframe)
    end
  end
end
