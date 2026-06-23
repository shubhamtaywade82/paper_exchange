module PaperExchange
  class MarginManager
    MARGIN_RATIOS = {
      "equity" => 0.10,
      "future" => 0.12,
      "option" => 0.20
    }.freeze

    def required_for_position(position, current_price)
      value = current_price * position.quantity
      ratio = MARGIN_RATIOS[position.instrument_type] || MARGIN_RATIOS["equity"]
      value * ratio
    end

    def available(account_id, used_margin)
      total_margin = ENV.fetch("PAPER_EXCHANGE_MARGIN", "100000").to_f
      total_margin - used_margin
    end
  end
end
