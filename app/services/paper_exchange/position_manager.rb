module PaperExchange
  class PositionManager
    def initialize(account_id:)
      @account_id = account_id
    end

    def find_or_create_for(order, fill_price:, quantity:)
      PaperExchange::PaperPosition.transaction do
        position = PaperExchange::PaperPosition.lock.find_by(
          account_id: @account_id,
          symbol: order.symbol,
          instrument_type: order.instrument_type,
          option_type: order.option_type,
          strike_price: order.strike_price,
          expiry_date: order.expiry_date,
          side: position_side(order.side)
        )

        unless position
          position = PaperExchange::PaperPosition.new(
            account_id: @account_id,
            symbol: order.symbol,
            instrument_type: order.instrument_type,
            option_type: order.option_type,
            strike_price: order.strike_price,
            expiry_date: order.expiry_date,
            side: position_side(order.side),
            quantity: 0,
            avg_price: 0,
            current_price: fill_price
          )
        end

        total_cost = (position.avg_price * position.quantity) + (fill_price * quantity)
        new_qty = position.quantity + quantity
        position.avg_price = new_qty > 0 ? total_cost / new_qty : 0
        position.quantity = new_qty
        position.current_price = fill_price
        position.unrealized_pnl = PnLEngine.unrealized_pnl(position, position.current_price)
        position.save!
      end

      position
    end

    private

    def position_side(order_side)
      case order_side
      when "buy", PaperExchange::PaperOrder.sides[:buy]
        "long"
      when "sell", PaperExchange::PaperOrder.sides[:sell]
        "short"
      else
        raise ArgumentError, "Unknown side: #{order_side}"
      end
    end
  end
end
