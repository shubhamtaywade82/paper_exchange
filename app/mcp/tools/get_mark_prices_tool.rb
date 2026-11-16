# frozen_string_literal: true

class GetMarkPricesTool < ApplicationMCPTool
  tool_name "get_mark_prices"
  description "Fetch current mark prices for one or all trading symbols"

  property :symbol, type: "string", description: "Optional specific symbol (e.g. BTCUSDT)"

  def perform
    if symbol.present?
      normalized = symbol.upcase
      price = MarketData::MarkPriceStore.get(normalized)
      render_json(
        symbol: normalized,
        price: price&.to_s,
        status: price.present? ? "live" : "unavailable"
      )
    else
      prices = MarketData::MarkPriceStore.all
      render_json(
        count: prices.size,
        prices: prices
      )
    end
  end
end
