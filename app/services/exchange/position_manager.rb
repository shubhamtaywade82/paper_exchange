module Exchange
  class PositionManager
    def self.apply!(account_id:, symbol:, side:, quantity:, avg_price:)
      normalized_side = normalize_side(side)
      total_qty = quantity.is_a?(Numeric) ? quantity : quantity.to_i
      existing = ::PaperExchange::PaperPosition.find_by(
        account_id: account_id,
        symbol: symbol,
        side: normalized_side
      )

      if existing
        position = existing
        position.quantity ||= 0
        position.avg_price ||= 0.0
        position.quantity += total_qty
        # Reset avg price when reducing/zeroing position
        if position.quantity <= 0
          position.quantity = 0
          position.avg_price = 0
        elsif total_qty > 0
          total_cost = (position.avg_price * (position.quantity - total_qty)) + (avg_price.to_f * total_qty)
          position.avg_price = total_cost / position.quantity
        end
        position.current_price = avg_price
        position.save!
        position
      else
        # Check if this new position offsets the opposite side
        opposite_side = normalized_side == 'long' ? 'short' : 'long'
        opposite = ::PaperExchange::PaperPosition.find_by(
          account_id: account_id,
          symbol: symbol,
          side: opposite_side
        )

        if opposite && opposite.quantity.to_i > 0
          net = total_qty - opposite.quantity
          if net >= 0
            opposite.destroy!
            return apply!(account_id: account_id, symbol: symbol, side: side, quantity: net, avg_price: avg_price)
          else
            opposite.quantity = opposite.quantity + total_qty
            opposite.save!
            return opposite
          end
        end

        position = ::PaperExchange::PaperPosition.new(
          account_id: account_id,
          symbol: symbol,
          side: normalized_side,
          quantity: [total_qty, 0].max,
          avg_price: avg_price.to_f,
          current_price: avg_price.to_f
        )
        position.save!
        position
      end
    end

    def self.normalize_side(side)
      case side.to_s.downcase
      when /buy/ then 'long'
      when /sell/ then 'short'
      else side.to_s
      end
    end
  end
end
