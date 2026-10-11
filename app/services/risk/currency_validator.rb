module Risk
  # P1-6 fix: currency consistency gate. Accounts are denominated in a single
  # currency (INR, USD, or USDT). Indian instruments (EQUITY, F&O via Dhan)
  # settle in INR; crypto perpetuals (Binance, CoinDCX) settle in USDT.
  # Previously the same account could mix rupee-denominated Indian instruments
  # and USDT-denominated crypto positions, aggregating raw numeric PnL across
  # currencies — a meaningless sum.
  #
  # This validator rejects an order whose instrument's settlement currency
  # does not match the account's currency, so each account is currency-pure.
  # The mapping is:
  #   EQUITY, FUTIDX, OPTIDX, FUTSTK, OPTSTK, FUTCUR, OPTCUR, FUTCOM, OPTFUT → INR
  #   CRYPTO_PERPETUAL → USDT (or USD, depending on the account's setup)
  class CurrencyValidator
    INSTRUMENT_CURRENCY = {
      "EQUITY" => "INR",
      "FUTIDX" => "INR", "OPTIDX" => "INR",
      "FUTSTK" => "INR", "OPTSTK" => "INR",
      "FUTCUR" => "INR", "OPTCUR" => "INR",
      "FUTCOM" => "INR", "OPTFUT" => "INR",
      "CRYPTO_PERPETUAL" => "USDT"
    }.freeze

    def evaluate(account_id, signal)
      h = signal.to_h
      instrument_type = h[:instrument_type].to_s
      instrument_currency = INSTRUMENT_CURRENCY[instrument_type]

      # Unknown instrument types pass through — the OrderValidator already
      # rejects invalid instrument types before the risk gate runs.
      return :passed unless instrument_currency

      account = Account.find_by(account_id: account_id)
      return :passed unless account

      # An account in USD can trade crypto (USDT ≈ USD for paper trading).
      # An account in INR can trade Indian instruments. Cross-currency is
      # rejected so the wallet is never a meaningless mixed-currency sum.
      if currency_match?(account.currency, instrument_currency)
        :passed
      else
        :CURRENCY_MISMATCH_REJECTED
      end
    end

    private

    # USD and USDT are treated as compatible for paper-trading purposes so
    # a single USD-denominated account can trade crypto perpetuals without
    # forcing the operator to set up a separate USDT account.
    def currency_match?(account_currency, instrument_currency)
      return true if account_currency == instrument_currency
      return true if account_currency == "USD" && instrument_currency == "USDT"
      return true if account_currency == "USDT" && instrument_currency == "USD"
      false
    end
  end
end
