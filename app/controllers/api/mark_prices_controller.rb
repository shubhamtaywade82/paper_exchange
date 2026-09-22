module Api
  class MarkPricesController < BaseController
    # Bot-pushed Binance mark prices — the only source of live crypto market
    # data this broker has (it does not open its own exchange WebSocket; see
    # README "Crypto market data ownership"). Push at whatever cadence your
    # own feed updates: liquidation checks for leveraged positions only run
    # when a price for their symbol arrives here, so a symbol with an open
    # leveraged position should be pushed frequently (every few seconds).
    #
    # Payload: { "prices": { "BTCUSDT": "65123.45", "ETHUSDT": "3200.10" } }
    def create
      prices = params.require(:prices).to_unsafe_h
      raise ActionController::ParameterMissing, :prices if prices.blank?

      Risk::LiquidationEngine.refresh_cache!

      updated = prices.filter_map do |symbol, price|
        next if price.blank?

        applied = MarketData::MarkPriceStore.set(symbol, price)
        Risk::LiquidationEngine.check_symbol!(symbol, applied)
        [symbol.to_s.upcase, applied]
      end.to_h

      render json: { updated: updated }, status: :ok
    rescue ActionController::ParameterMissing => e
      render_error(:bad_request, e.message)
    end
  end
end
