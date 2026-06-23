module Domains
  module MarketData
    class OrderEvent
      attr_reader :order_id, :account_id, :symbol, :side, :order_type, :quantity, :price, :trigger_price, :status, :timestamp

      def initialize(order_id:, account_id:, symbol:, side:, order_type:, quantity:, price: nil, trigger_price: nil, status: "pending", timestamp: Time.current)
        @order_id = order_id
        @account_id = account_id
        @symbol = symbol
        @side = side
        @order_type = order_type
        @quantity = quantity
        @price = price
        @trigger_price = trigger_price
        @status = status
        @timestamp = timestamp
      end

      def to_h
        {
          order_id: order_id,
          account_id: account_id,
          symbol: symbol,
          side: side,
          order_type: order_type,
          quantity: quantity,
          price: price,
          trigger_price: trigger_price,
          status: status,
          timestamp: timestamp
        }
      end
    end
  end
end
