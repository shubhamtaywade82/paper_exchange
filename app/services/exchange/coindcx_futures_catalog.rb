require "cgi"

module Exchange
  class CoinDCXFuturesCatalog
    # NOTE: CoinDCX does not expose an unauthenticated list-all endpoint for futures.
    # The public instrument detail endpoint requires a known `pair` parameter.
    # Format: B-{SYMBOL}_{QUOTE}, e.g. B-BTC_USDT
    BaseUrl = "https://api.coindcx.com/exchange/v1/derivatives/futures/data/".freeze

    class << self
      def fetch_instrument(pair)
        url = "#{BaseUrl}instrument?pair=#{CGI.escape(pair)}"
        response = Faraday.get(url)
        raise "CoinDCX instrument fetch failed: #{response.status}" unless response.success?

        data = JSON.parse(response.body)
        instrument = data["instrument"]
        return nil unless instrument

        {
          exchange: "coindcx",
          symbol: pair,
          base_asset: instrument["position_currency_short_name"],
          quote_asset: instrument["quote_currency_short_name"],
          contract_type: instrument["kind"],
          underlying_type: nil,
          price_precision: precision_for(instrument["price_increment"]),
          quantity_precision: precision_for(instrument["quantity_increment"]),
          min_price: instrument["min_price"]&.to_f,
          tick_size: instrument["price_increment"]&.to_f,
          min_qty: instrument["min_quantity"]&.to_f,
          max_qty: instrument["max_quantity"]&.to_f,
          lot_size: instrument["quantity_increment"]&.to_f,
          min_notional: instrument["min_notional"]&.to_f,
          maker_fee: instrument["maker_fee"]&.to_f,
          taker_fee: instrument["taker_fee"]&.to_f
        }
      rescue Faraday::Error => e
        raise "CoinDCX instrument fetch error: #{e.message}"
      end

      def fetch_instruments_for_pairs(pairs)
        pairs.filter_map { |pair| fetch_instrument(pair) }
      end

      private

      def precision_for(value)
        return nil unless value
        value = value.to_s
        return 0 if value.exclude?(".")
        value.split(".").last.length
      end
    end
  end
end
