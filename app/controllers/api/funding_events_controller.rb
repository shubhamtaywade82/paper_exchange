module Api
  class FundingEventsController < BaseController
    # The trading bot (owner of the Binance market-data connection) calls
    # this when a perpetual futures funding settlement happens for a symbol.
    # Enqueues FundingJob to post the funding fee against every open
    # leveraged position on that symbol.
    #
    # Payload: { "symbol": "BTCUSDT", "funding_rate": "0.0001", "mark_price": "65000.0",
    #            "funding_time": "2026-09-20T08:00:00Z" }
    # `mark_price` is optional — falls back to MarketData::MarkPriceStore.
    # `funding_time` is the idempotency key — pass Binance's funding
    # settlement timestamp so an HTTP retry doesn't double-charge funding.
    #
    # Boundary validation (audit M3): an unbounded funding_rate used to pass
    # straight through .to_f — a fat-fingered "1.0" (100% per settlement)
    # posted a monstrous fee against every open position. Rates are bounded
    # to a sane per-settlement band, and an unparseable funding_time is
    # rejected 422 instead of casting to nil, which silently bypassed the
    # (paper_position_id, funding_time) dedup index.
    MAX_FUNDING_RATE = 0.05
    MAX_MARK_PRICE = 1e15

    class InvalidInput < StandardError; end

    def create
      symbol = params.require(:symbol)
      rate = parse_funding_rate!(params.require(:funding_rate))
      mark_price = parse_optional_mark_price!(params[:mark_price])
      funding_time = parse_optional_funding_time!(params[:funding_time])

      args = [ symbol.to_s.upcase, rate, mark_price ]
      args << funding_time if funding_time
      if params[:sync].present?
        FundingJob.perform_now(*args)
      else
        FundingJob.perform_later(*args)
      end

      render json: { accepted: true, symbol: symbol.to_s.upcase }, status: :accepted
    rescue ActionController::ParameterMissing => e
      render_error(:bad_request, e.message)
    rescue InvalidInput => e
      render_error(:unprocessable_content, e.message)
    end

    private

    def parse_funding_rate!(raw)
      rate = Float(raw, exception: false)
      return rate if rate.is_a?(Numeric) && rate.finite? && rate.abs <= MAX_FUNDING_RATE

      raise InvalidInput, "invalid funding_rate #{raw.inspect}: must be a finite number with abs value <= #{MAX_FUNDING_RATE}"
    end

    def parse_optional_mark_price!(raw)
      return nil if raw.blank?

      price = Float(raw, exception: false)
      return price if price.is_a?(Numeric) && price.finite? && price.positive? && price <= MAX_MARK_PRICE

      raise InvalidInput, "invalid mark_price #{raw.inspect}: must be a finite number > 0 and <= #{MAX_MARK_PRICE}"
    end

    def parse_optional_funding_time!(raw)
      return nil if raw.blank?

      parsed = Time.zone.parse(raw.to_s)
      return parsed if parsed

      raise InvalidInput, "invalid funding_time #{raw.inspect}: must be a parseable timestamp (e.g. 2026-09-20T08:00:00Z)"
    end
  end
end
