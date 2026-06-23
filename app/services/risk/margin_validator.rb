module Risk
  class MarginValidator
    MARGIN_RATIOS = { "EQUITY" => 0.10, "FUTIDX" => 0.12, "OPTIDX" => 0.20, "FUTCUR" => 0.12, "OPTCUR" => 0.20 }.freeze
    MAX_POSITION_VALUE = (ENV.fetch("PAPER_EXCHANGE_MAX_POSITION_VALUE", "500000").to_f)

    def evaluate(account_id, signal)
      symbol = signal.to_h[:symbol]
      qty = signal.to_h[:quantity]
      price = signal.to_h[:price] || signal.to_h[:ltp]
      instrument_type = signal.to_h[:instrument_type] || "EQUITY"
      notional = price * qty
      return :passed if notional <= MAX_POSITION_VALUE

      :MARGIN_REJECTED
    end
  end
end
