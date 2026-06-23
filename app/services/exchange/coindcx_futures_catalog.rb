require "coindcx"

module Exchange
  class CoinDCXFuturesCatalog
    DEFAULT_MARGIN_CURRENCIES = %w[USDT USDC BUSD].freeze

    # Fetch all active futures instruments for the given margin currencies.
    # Delegates to the coindcx-client gem.
    def self.fetch_instruments(margin_currency_short_names: DEFAULT_MARGIN_CURRENCIES)
      client = CoinDCX::Client.new(configuration: CoinDCX::Configuration.new)
      response = client.futures.market_data.list_active_instruments(margin_currency_short_names: margin_currency_short_names)
      Array(response).map { |inst| normalize(inst) }
    rescue => e
      raise "CoinDCX active instruments fetch error: #{e.message}"
    end

    # Fetch a single futures instrument by pair.
    def self.fetch_instrument(pair, margin_currency_short_name: "USDT")
      client = CoinDCX::Client.new(configuration: CoinDCX::Configuration.new)
      response = client.futures.market_data.fetch_instrument(
        pair: pair,
        margin_currency_short_name: margin_currency_short_name
      )
      normalize(response)
    rescue => e
      raise "CoinDCX instrument fetch error: #{e.message}"
    end

    def self.normalize(data)
      return nil unless data

      {
        exchange: "coindcx",
        symbol: data[:pair] || data["pair"],
        base_asset: data[:position_currency_short_name] || data["position_currency_short_name"],
        quote_asset: data[:quote_currency_short_name] || data["quote_currency_short_name"],
        contract_type: data[:kind] || data["kind"],
        underlying_type: nil,
        price_precision: precision_for(data[:price_increment] || data["price_increment"]),
        quantity_precision: precision_for(data[:quantity_increment] || data["quantity_increment"]),
        min_price: data[:min_price]&.to_f,
        tick_size: (data[:price_increment] || data["price_increment"])&.to_f,
        min_qty: data[:min_quantity]&.to_f,
        max_qty: data[:max_quantity]&.to_f,
        lot_size: (data[:quantity_increment] || data["quantity_increment"])&.to_f,
        min_notional: data[:min_notional]&.to_f,
        maker_fee: data[:maker_fee]&.to_f,
        taker_fee: data[:taker_fee]&.to_f
      }
    end

    def self.precision_for(value)
      return nil unless value
      value = value.to_s
      return 0 if value.exclude?(".")
      value.split(".").last.length
    end
  end
end
