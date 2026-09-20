module Risk
  # Margin gate. Two checks:
  #   1. Notional must not exceed MAX_POSITION_VALUE (single-order cap, all
  #      instrument types).
  #   2. Required margin (notional / leverage for crypto perps, full notional
  #      for unleveraged) must not exceed the account's available_balance.
  #
  # Without check #2, an over-leveraged order would sail through here, then
  # fail at MarginLedger.lock_margin! AFTER the order is already saved and
  # the client has been told it's accepted (depending on timing). Check #2
  # rejects before any state mutation.
  class MarginValidator
    MAX_POSITION_VALUE = ENV.fetch("PAPER_EXCHANGE_MAX_POSITION_VALUE", "500000").to_f

    def evaluate(account_id, signal)
      h = signal.to_h
      qty = h[:quantity].to_f   # was .to_i — silently zeroed every fractional crypto order
      price = (h[:price] || h[:ltp]).to_f
      instrument_type = h[:instrument_type].to_s.presence || "EQUITY"
      leverage = h[:leverage].to_i
      leverage = 1 if leverage < 1

      notional = price * qty
      return :MARGIN_REJECTED if notional > MAX_POSITION_VALUE

      required_margin = notional / leverage
      account = Account.find_by(account_id: account_id)
      return :passed unless account   # no account row → fall through to MarginLedger which will raise

      account.available_balance.to_f >= required_margin ? :passed : :MARGIN_REJECTED
    end
  end
end
