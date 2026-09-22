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
    def create
      symbol = params.require(:symbol)
      funding_rate = params.require(:funding_rate)
      mark_price = params[:mark_price].presence
      funding_time = params[:funding_time].presence

      args = [ symbol.to_s.upcase, funding_rate.to_f, mark_price&.to_f ]
      args << funding_time if funding_time.present?
      if params[:sync].present?
        FundingJob.perform_now(*args)
      else
        FundingJob.perform_later(*args)
      end

      render json: { accepted: true, symbol: symbol.to_s.upcase }, status: :accepted
    rescue ActionController::ParameterMissing => e
      render_error(:bad_request, e.message)
    end
  end
end
