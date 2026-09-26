module Risk
  # Margin gate. Two checks:
  #   1. Notional must not exceed MAX_POSITION_VALUE (single-order cap, all
  #      instrument types).
  #   2. Required margin must not exceed the account's available_balance:
  #      notional / leverage for leveraged crypto perps, FULL notional for
  #      unleveraged instruments (audit S3/T3.5 — the lock in submit_order
  #      takes the full notional for leverage-1 orders, so the gate must
  #      compare against the same figure; the old ratio-based check let
  #      oversized equity orders past the gate to die later at
  #      MarginLedger.lock_margin! with a 402 after the order row was
  #      already saved).
  #
  # Check #2 rejects before any state mutation — the client gets a clean
  # 422 instead of a 402 mid-flight.
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

      required_margin = if instrument_type == "CRYPTO_PERPETUAL"
        notional / leverage
      else
        notional
      end

      account = Account.find_by(account_id: account_id)
      return :passed unless account   # no account row → fall through to MarginLedger which will raise

      account.available_balance.to_f >= required_margin ? :passed : :MARGIN_REJECTED
    end
  end
end
