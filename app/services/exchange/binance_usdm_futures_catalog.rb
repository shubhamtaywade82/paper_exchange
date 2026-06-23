module Exchange
  class BinanceUsdMFuturesCatalog
    BaseUrl = "https://fapi.binance.com".freeze

    class << self
      def fetch_instruments
        response = Faraday.get("#{BaseUrl}/fapi/v1/exchangeInfo")
        raise "Binance USD-M fetch failed: #{response.status}" unless response.success?

        data = JSON.parse(response.body)
        symbols = data["symbols"] || []

        symbols.filter_map do |s|
          next unless s["status"] == "TRADING"
          next unless s["contractType"] == "PERPETUAL"
          next unless s["underlyingType"] == "COIN"

          filters = s["filters"] || []
          {
            exchange: "binance_usdm",
            symbol: s["symbol"],
            base_asset: s["baseAsset"],
            quote_asset: s["quoteAsset"],
            contract_type: s["contractType"],
            underlying_type: s["underlyingType"],
            price_precision: s["pricePrecision"],
            quantity_precision: s["quantityPrecision"],
            min_price: filter_value(filters, "PRICE_FILTER", "minPrice"),
            tick_size: filter_value(filters, "PRICE_FILTER", "tickSize"),
            min_qty: filter_value(filters, "LOT_SIZE", "minQty"),
            max_qty: filter_value(filters, "LOT_SIZE", "maxQty"),
            lot_size: filter_value(filters, "LOT_SIZE", "stepSize"),
            min_notional: filter_value(filters, "NOTIONAL", "notional"),
            maker_fee: nil,
            taker_fee: nil,
            on_board_date: s["onboardDate"] ? Time.at(s["onboardDate"] / 1000) : nil
          }
        end
      rescue Faraday::Error => e
        raise "Binance USD-M instrument fetch error: #{e.message}"
      end

      private

      def filter_value(filters, filter_type, key)
        f = filters.find { |x| x["filterType"] == filter_type }
        f ? f[key].to_f : nil
      end
    end
  end
end
