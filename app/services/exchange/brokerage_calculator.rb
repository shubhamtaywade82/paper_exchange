module Exchange
  # Trade charge entry point used by FillEngine and margin sizing.
  #
  # India instruments (equity, index and stock futures and options) are costed by
  # Charges::Calculator from effective-dated ChargeRule rows. A missing rule raises;
  # nothing is defaulted.
  #
  # Crypto is not yet on rule rows. Its schedule still comes from ENV and constants
  # below, and it moves to rows in a later step. Its arithmetic is decimal.
  class BrokerageCalculator
    def initialize
      # Crypto options (Binance Options schedule): the fee is a rate on the
      # underlying's notional, capped at a fraction of the premium. Defaults are the
      # published taker tier; an account's own tier is what
      # GET /eapi/v1/commission returns, so pin these to that.
      @crypto_option_fee_rate = BigDecimal(ENV.fetch("PAPER_EXCHANGE_CRYPTO_OPTION_FEE_RATE", "0.0003"))
      @crypto_option_fee_cap = BigDecimal(ENV.fetch("PAPER_EXCHANGE_CRYPTO_OPTION_FEE_CAP", "0.10"))
    end

    def calculate(trade_price:, quantity:, side:, symbol:, instrument_type: "EQUITY", at: Clock.now)
      return crypto_option_charges(trade_price, quantity, symbol) if instrument_type == "CRYPTO_OPTION"
      return crypto_perpetual_charges(trade_price, quantity) if instrument_type == "CRYPTO_PERPETUAL"

      Charges::Calculator.new.calculate(
        trade_price: trade_price, quantity: quantity, side: side, instrument_type: instrument_type, at: at
      )
    end

    def margin_required_for(trade_price:, quantity:, side:, symbol:, instrument_type: "EQUITY")
      fees = calculate(trade_price: trade_price, quantity: quantity, side: side, symbol: symbol, instrument_type: instrument_type)
      fees[:notional] + fees[:total]
    end

    private

    def crypto_perpetual_charges(trade_price, quantity)
      turnover = BigDecimal(trade_price.to_s) * BigDecimal(quantity.to_s)
      fee = (turnover * BigDecimal("0.0004")).round(8)
      {
        brokerage: fee, stt: 0, gst: 0, sebi: 0, stamp_duty: 0, exchange_txn: 0,
        total: fee, notional: turnover.round(8), rule_ids: []
      }
    end

    # min(rate x underlying index x qty, cap x premium x qty). Without a pushed
    # underlying price the cap alone is charged: it is the upper bound of the
    # formula, so a missing price can only overstate the cost.
    def crypto_option_charges(premium, quantity, symbol)
      premium_turnover = BigDecimal(premium.to_s) * BigDecimal(quantity.to_s)
      cap = premium_turnover * @crypto_option_fee_cap
      underlying = CryptoInstrumentCatalog.option_underlying(symbol)
      index_price = underlying && MarketData::MarkPriceStore.get(underlying)
      fee = if index_price && BigDecimal(index_price.to_s).positive?
        [ @crypto_option_fee_rate * BigDecimal(index_price.to_s) * BigDecimal(quantity.to_s), cap ].min
      else
        cap
      end
      fee = fee.round(8)
      {
        brokerage: fee, stt: 0, gst: 0, sebi: 0, stamp_duty: 0, exchange_txn: 0,
        total: fee, notional: premium_turnover.round(8), rule_ids: []
      }
    end
  end
end
