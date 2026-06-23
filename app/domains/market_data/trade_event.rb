module Domains
  module MarketData
    class TradeEvent
      attr_reader :trade_id, :order_id, :account_id, :symbol, :side, :quantity, :price, :charges, :traded_at

      def initialize(trade_id:, order_id:, account_id:, symbol:, side:, quantity:, price:, charges: {}, traded_at: Time.current)
        @trade_id = trade_id
        @order_id = order_id
        @account_id = account_id
        @symbol = symbol
        @side = side
        @quantity = quantity
        @price = price
        @charges = charges
        @traded_at = traded_at
      end

      def to_h
        {
          trade_id: trade_id,
          order_id: order_id,
          account_id: account_id,
          symbol: symbol,
          side: side,
          quantity: quantity,
          price: price,
          charges: charges,
          traded_at: traded_at
        }
      end
    end
  end
end
