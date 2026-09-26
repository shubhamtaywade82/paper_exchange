module Api
  class StrategyController < BaseController
    # POST /api/strategy/signals — read-only pre-trade risk assessment:
    # "would this signal pass the risk gate right now?" Runs the exact
    # gate POST /api/orders runs (RiskManager decides only — no RiskEvent
    # rows, no order, no margin lock) and adds the symbol's latest
    # market-structure snapshot for context. Submit the trade itself via
    # POST /api/orders.
    #
    # Payload (nested under "signal" or bare at the root, like orders):
    #   { "signal": { "symbol": "RELIANCE", "side": "buy", "quantity": 2,
    #                 "order_kind": "market", "instrument_type": "EQUITY",
    #                 "ltp": 2500.0, "leverage": 1,
    #                 "context": { "vix": 14.2 } },
    #     "timeframe": "5m" }   # market-structure context to attach
    #
    # 200 either way — `decision` is allow|reject; `rejections` carries
    # the *_REJECTED symbols (same vocabulary as /api/risk_events).
    class InvalidInput < StandardError; end

    INSTRUMENT_TYPES = (Exchange::DhanInstrumentCatalog::INSTRUMENT_TYPES +
                        Exchange::CryptoInstrumentCatalog::INSTRUMENT_TYPES).freeze

    def create
      signal = build_signal
      timeframe = parse_timeframe

      result = Strategy::StrategyEngine.new(
        indicator_engine: Strategy::IndicatorEngine.new,
        market_structure_engine: Strategy::MarketStructureEngine.new
      ).assess(signal)

      snapshot = Strategy::MarketStructureEngine.new.snapshot(signal.symbol, timeframe: timeframe)

      render json: result.merge(
        signal: signal_json(signal),
        market_structure: snapshot ? structure_json(snapshot) : nil,
        timeframe: timeframe
      )
    rescue InvalidInput => e
      render_error(:unprocessable_content, e.message)
    end

    private

    def raw
      params[:signal].presence || params
    end

    def parse_timeframe
      timeframe = params[:timeframe].presence&.to_s&.downcase || "5m"
      raise InvalidInput, "invalid timeframe #{params[:timeframe].inspect} (max 8 chars)" unless timeframe.match?(/\A[a-z0-9]{1,8}\z/)

      timeframe
    end

    def build_signal
      symbol = raw[:symbol].presence&.to_s&.strip&.upcase
      raise InvalidInput, "symbol is required (A-Z0-9._-, max 32 chars)" unless symbol&.match?(/\A[A-Z0-9._-]{1,32}\z/)

      side = raw[:side].presence&.to_s&.downcase
      raise InvalidInput, "side must be buy or sell" unless %w[buy sell].include?(side)

      quantity = Float(raw[:quantity], exception: false)
      raise InvalidInput, "invalid quantity #{raw[:quantity].inspect}: must be a finite number > 0" unless quantity&.finite? && quantity.positive?

      instrument_type = raw[:instrument_type].presence&.to_s&.upcase || "EQUITY"
      raise InvalidInput, "invalid instrument_type #{instrument_type} (one of #{INSTRUMENT_TYPES.join(', ')})" unless INSTRUMENT_TYPES.include?(instrument_type)

      ltp = raw[:ltp]
      if ltp.present?
        ltp = Float(ltp, exception: false)
        raise InvalidInput, "invalid ltp #{raw[:ltp].inspect}: must be a finite number > 0" unless ltp&.finite? && ltp.positive?
      end

      leverage = raw[:leverage].presence
      if leverage
        leverage = Integer(leverage, exception: false)
        raise InvalidInput, "invalid leverage #{raw[:leverage].inspect}: must be an integer >= 1" if leverage.nil? || leverage < 1
      end

      option_type = raw[:option_type].presence&.to_s&.upcase
      raise InvalidInput, "invalid option_type #{raw[:option_type].inspect}: CE or PE" if option_type && !%w[CE PE].include?(option_type)

      Strategy::Signal.new(
        account_id: @account_id,
        symbol: symbol,
        side: side,
        quantity: quantity,
        order_kind: raw[:order_kind].presence&.to_s&.downcase || "market",
        instrument_type: instrument_type,
        option_type: option_type,
        ltp: ltp,
        leverage: leverage || 1,
        context: parse_context
      )
    end

    # context passes through to the validators (VixGate reads context[:vix]).
    def parse_context
      context = raw[:context]
      return {} unless context.is_a?(ActionController::Parameters) || context.is_a?(Hash)

      context = context.to_unsafe_h if context.respond_to?(:to_unsafe_h)
      context = context.symbolize_keys

      if context.key?(:vix) && context[:vix].present?
        vix = Float(context[:vix], exception: false)
        raise InvalidInput, "invalid context.vix #{context[:vix].inspect}: must be a finite number" unless vix&.finite?

        context[:vix] = vix
      end
      context
    end

    def signal_json(signal)
      {
        symbol: signal.symbol,
        side: signal.side,
        quantity: signal.quantity,
        order_kind: signal.order_type,
        instrument_type: signal.instrument_type,
        option_type: signal.option_type,
        ltp: signal.ltp,
        leverage: signal.leverage,
        context: signal.context
      }
    end

    def structure_json(snapshot)
      {
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
