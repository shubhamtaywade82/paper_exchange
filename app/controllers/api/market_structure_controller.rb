module Api
  class MarketStructureController < BaseController
    # Smart-money-concepts market-structure context per symbol+timeframe,
    # pushed by the analysis side of the feed owner. Snapshots are
    # append-only rows (market_structure_snapshots); reads always take
    # the newest per (symbol, timeframe).
    #
    # POST payload (all flags optional unless noted):
    #   { "symbol": "BTCUSDT",            # required, A-Z0-9._-, max 32
    #     "timeframe": "5m",              # default 5m, lowercase, max 8
    #     "trend": "bullish",             # bullish|bearish|range|neutral
    #     "bos": true, "choch": false,    # break of structure / change of character
    #     "bullish_fvg_count": 2,         # >= 0
    #     "bearish_fvg_count": 1,         # >= 0
    #     "liquidity_sweep": "sell_side", # free tag, max 32 chars
    #     "order_block": "bullish_ob",    # free tag, max 32 chars
    #     "premium_discount": "premium",  # free tag, max 32 chars
    #     "as_of": "2026-09-26T10:00:00Z" } # optional, must parse
    #
    # GET /api/market_structure?symbol=BTCUSDT&timeframe=5m — the latest
    # snapshot for one symbol (404 when none yet), or without symbol the
    # latest per symbol for the timeframe.
    TREND_VALUES = %w[bullish bearish range neutral].freeze
    MAX_TAG_LENGTH = 32

    class InvalidInput < StandardError; end

    def create
      symbol = parse_symbol
      timeframe = parse_timeframe
      trend = parse_trend
      counts = parse_fvg_counts
      tags = parse_tags
      as_of = parse_as_of

      snapshot = Strategy::MarketStructureEngine.new.ingest(
        symbol, timeframe: timeframe, trend: trend,
        bos: ActiveModel::Type::Boolean.new.cast(params[:bos]) || false,
        choch: ActiveModel::Type::Boolean.new.cast(params[:choch]) || false,
        bullish_fvg_count: counts[0], bearish_fvg_count: counts[1],
        liquidity_sweep: tags[0], order_block: tags[1], premium_discount: tags[2],
        as_of: as_of
      )

      render json: snapshot_json(snapshot), status: :created
    rescue InvalidInput => e
      render_error(:unprocessable_content, e.message)
    end

    def index
      timeframe = parse_timeframe(optional: true)
      engine = Strategy::MarketStructureEngine.new

      if params[:symbol].present?
        snapshot = engine.snapshot(params[:symbol], timeframe: timeframe)
        return render_error(:not_found, "no market structure snapshot for #{params[:symbol].to_s.upcase} #{timeframe}") unless snapshot

        return render json: snapshot_json(snapshot)
      end

      render json: { data: engine.latest(timeframe: timeframe).map { |s| snapshot_json(s) }, timeframe: timeframe }
    end

    private

    def parse_symbol
      symbol = params[:symbol].presence&.to_s&.strip&.upcase
      raise InvalidInput, "symbol is required (A-Z0-9._-, max 32 chars)" unless symbol&.match?(/\A[A-Z0-9._-]{1,32}\z/)

      symbol
    end

    def parse_timeframe(optional: false)
      timeframe = params[:timeframe].presence&.to_s&.downcase || "5m"
      raise InvalidInput, "invalid timeframe #{params[:timeframe].inspect} (max 8 chars)" unless timeframe.match?(/\A[a-z0-9]{1,8}\z/)

      timeframe
    end

    def parse_trend
      return nil if params[:trend].blank?

      trend = params[:trend].to_s.downcase
      raise InvalidInput, "invalid trend #{params[:trend].inspect}: one of #{TREND_VALUES.join('|')}" unless TREND_VALUES.include?(trend)

      trend
    end

    def parse_fvg_counts
      %w[bullish_fvg_count bearish_fvg_count].map do |field|
        next 0 if params[field].blank?

        value = Integer(params[field], exception: false)
        raise InvalidInput, "invalid #{field} #{params[field].inspect}: must be an integer >= 0" if value.nil? || value.negative?

        value
      end
    end

    def parse_tags
      %w[liquidity_sweep order_block premium_discount].map do |field|
        next nil if params[field].blank?

        params[field].to_s.slice(0, MAX_TAG_LENGTH)
      end
    end

    def parse_as_of
      return Time.current if params[:as_of].blank?

      parsed = begin
        Time.zone.parse(params[:as_of].to_s)
      rescue ArgumentError
        nil
      end
      raise InvalidInput, "invalid as_of #{params[:as_of].inspect}: must be a parseable timestamp" unless parsed

      parsed
    end

    def snapshot_json(snapshot)
      {
        id: snapshot.id,
        symbol: snapshot.symbol,
        timeframe: snapshot.timeframe,
        trend: snapshot.trend,
        last_bos: snapshot.last_bos,
        last_choch: snapshot.last_choch,
        bullish_fvg_count: snapshot.bullish_fvg_count,
        bearish_fvg_count: snapshot.bearish_fvg_count,
        liquidity_sweep: snapshot.liquidity_sweep,
        order_block: snapshot.order_block,
        premium_discount: snapshot.premium_discount,
        as_of: snapshot.as_of
      }
    end
  end
end
