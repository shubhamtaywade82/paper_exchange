module PaperExchange
  class OrderManager
    def initialize(matching_engine:, market_data_feed:)
      @matching_engine = matching_engine
      @market_data_feed = market_data_feed
    end

    def place_order(attrs)
      order = PaperOrder.new(order_attrs(attrs))
      PaperOrder.transaction do
        order.save!
        order.open!
        @matching_engine.execute(order)
        order
      end
    end

    def cancel_order(order_id, account_id:)
      order = PaperOrder.find(order_id)
      return false unless order.pending? || order.open?

      order.cancel!
    end

    private

    def order_attrs(attrs)
      {
        account_id: attrs[:account_id],
        symbol: attrs[:symbol],
        side: attrs[:side],
        order_type: attrs.fetch(:order_type, :market),
        quantity: attrs[:quantity],
        price: attrs[:price],
        trigger_price: attrs[:trigger_price],
        instrument_type: attrs.fetch(:instrument_type, "equity"),
        option_type: attrs[:option_type],
        strike_price: attrs[:strike_price],
        expiry_date: attrs[:expiry_date]
      }
    end
  end
end
