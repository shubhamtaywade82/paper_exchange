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
    #
    # Boundary validation (audit M3): a garbage value ("abc", a nested
    # object, a fat-fingered exponent) used to become 0.0 via .to_f, and a
    # 0.0 mark price trivially breaches every long's liquidation price — one
    # malformed push mass-liquidated accounts. Every value must parse as a
    # finite positive number within a sane band, or the WHOLE request is
    # rejected 422: nothing is applied, prior prices are retained, no
    # liquidation checks run.
    MAX_MARK_PRICE = 1e15

    def create
      prices = params.require(:prices).to_unsafe_h
      raise ActionController::ParameterMissing, :prices if prices.blank?

      parsed, invalid = parse_prices(prices)
      if invalid.any?
        return render_error(
          :unprocessable_content,
          "invalid mark price for: #{invalid.join(', ')} — each price must be a finite number > 0 and <= #{MAX_MARK_PRICE}"
        )
      end

      Risk::LiquidationEngine.refresh_cache!

      updated = parsed.map do |symbol, value|
        applied = MarketData::MarkPriceStore.set(symbol, value)
        Risk::LiquidationEngine.check_symbol!(symbol, applied)
        [ symbol, applied ]
      end.to_h

      render json: { updated: updated }, status: :ok
    rescue ActionController::ParameterMissing => e
      render_error(:bad_request, e.message)
    end

    private

    # Blank values are skipped (unchanged historical behavior); everything
    # else must validate. Returns [{symbol => value}, [invalid symbols]].
    def parse_prices(prices)
      parsed = {}
      invalid = []
      prices.each do |symbol, price|
        next if price.blank?

        value = Float(price, exception: false)
        if valid_price?(value)
          parsed[symbol.to_s.upcase] = value
        else
          invalid << symbol.to_s.upcase
        end
      end
      [ parsed, invalid ]
    end

    def valid_price?(value)
      value.is_a?(Numeric) && value.finite? && value.positive? && value <= MAX_MARK_PRICE
    end
  end
end
