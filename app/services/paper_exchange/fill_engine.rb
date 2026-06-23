module PaperExchange
  class FillEngine
    def initialize(brokerage_calculator:, event_bus:, position_manager:)
      @brokerage_calculator = brokerage_calculator
      @event_bus = event_bus
      @position_manager = position_manager
    end

    def fill(order, fill_price:, quantity:)
      PaperOrder.transaction do
        position = @position_manager.find_or_create_for(
          order,
          fill_price: fill_price,
          quantity: quantity
        )

        trade = PaperTrade.new(
          paper_order: order,
          paper_position: position,
          side: order.side,
          quantity: quantity,
          price: fill_price,
          traded_at: Time.current
        )

        charges = @brokerage_calculator.calculate(trade)
        trade.charges = charges
        trade.total_charges = charges[:total]
        trade.save!

        current_avg = order.avg_fill_price || 0
        current_qty = order.filled_quantity || 0
        total = (current_avg * current_qty) + (fill_price * quantity)
        new_qty = current_qty + quantity
        order.avg_fill_price = new_qty > 0 ? total / new_qty : fill_price
        order.filled_quantity = new_qty

        if order.filled_quantity >= order.quantity
          order.update!(filled_at: Time.current)
          order.filled!
        else
          order.partially_filled!
        end
        order.save!

        @event_bus.publish(
          :order_filled,
          order: order,
          price: fill_price,
          quantity: quantity,
          trade: trade
        )
      end
    end
  end
end
