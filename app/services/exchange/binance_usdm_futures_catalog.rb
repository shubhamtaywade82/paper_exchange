module Exchange
  class BinanceUsdMFuturesCatalog
    BaseUrl = "https://fapi.binance.com".freeze

    class << self
      def fetch_instruments
        response = Faraday.get("#{BaseUrl}/fapi/v1/exchangeInfo")
        raise "Binance USD-M futures API error: #{response.status}" unless response.success?

        data = JSON.parse(response.body)
        symbols = data["symbols"] || []

        symbols.map do |sym|
          filters = (sym["filters"] || []).index_by { |f| f["filterType"] }

          {
            exchange: "binance_usdm",
            symbol: sym["symbol"],
            base_asset: sym["baseAsset"],
            quote_asset: sym["quoteAsset"],
            contract_type: sym["contractType"],
            underlying_type: sym["underlyingType"],
            price_precision: sym["pricePrecision"],
            quantity_precision: sym["quantityPrecision"],
            min_price: nil,
            tick_size: price_filter_tick_size(filters["PRICE_FILTER"]),
            min_qty: lot_size_min_qty(filters["LOT_SIZE"]),
            max_qty: lot_size_max_qty(filters["LOT_SIZE"]),
            lot_size: lot_size_step_size(filters["LOT_SIZE"]),
            min_notional: notional_min_notional(filters["NOTIONAL"]),
            maker_fee: nil,
            taker_fee: nil
          }
        end
      end

      def fetch_instrument(symbol)
        fetch_instruments.find { |inst| inst[:symbol] == symbol }
      end

      def price_filter_tick_size(filter)
        return nil unless filter
        filter["tickSize"].to_f
      end

      def lot_size_min_qty(filter)
        return nil unless filter
        filter["minQty"].to_f
      end

      def lot_size_max_qty(filter)
        return nil unless filter
        filter["maxQty"].to_f
      end

      def lot_size_step_size(filter)
        return nil unless filter
        filter["stepSize"].to_f
      end

      def notional_min_notional(filter)
        return nil unless filter
        filter["notional"].to_f
      end
    end
  end
end
