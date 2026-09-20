module Api
  class FundingEventsController < BaseController
    # The trading bot (owner of the Binance market-data connection) calls
    # this when a perpetual futures funding settlement happens for a symbol.
    # Enqueues FundingJob to post the funding fee against every open
    # leveraged position on that symbol.
    #
    # Payload: { "symbol": "BTCUSDT", "funding_rate": "0.0001", "mark_price": "65000.0" }
    # `mark_price` is optional — falls back to MarketData::MarkPriceStore.
    def create
      symbol = params.require(:symbol)
      funding_rate = params.require(:funding_rate)
      mark_price = params[:mark_price].presence

      FundingJob.perform_later(symbol.to_s.upcase, funding_rate.to_f, mark_price&.to_f)

      render json: { accepted: true, symbol: symbol.to_s.upcase }, status: :accepted
    rescue ActionController::ParameterMissing => e
      render_error(:bad_request, e.message)
    end
  end
end
