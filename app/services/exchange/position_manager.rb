module Exchange
  class PositionManager
    def self.apply!(account_id:, symbol:, side:, quantity:, avg_price:)
      normalized_side = normalize_side(side)
      total_qty = quantity.is_a?(Numeric) ? quantity : quantity.to_i
      position = ::PaperExchange::PaperPosition.find_or_initialize_by(
        account_id: account_id,
        symbol: symbol,
        side: normalized_side
      )
      position.quantity ||= 0
      position.avg_price ||= 0

      position.quantity += total_qty
      position.avg_price = avg_price if position.quantity == total_qty
      if total_qty > 0 && position.quantity > 0
        total_cost = (position.avg_price * (position.quantity - total_qty)) + (avg_price * total_qty)
        position.avg_price = total_cost / position.quantity
      end
      position.current_price = avg_price

      position.save!
      position
    end

    def self.normalize_side(side)
      case side.to_s.downcase
      when /buy/ then "long"
      when /sell/ then "short"
      else side.to_s
      end
    end
  end
end
