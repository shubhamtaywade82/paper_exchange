module Strategy
  class Signal
    attr_reader :account_id, :symbol, :side, :quantity, :order_type, :instrument_type, :option_type, :strike_price, :expiry_date, :ltp, :context

    def initialize(account_id:, symbol:, side:, quantity:, order_kind: "market", instrument_type: "EQUITY", option_type: nil, strike_price: nil, expiry_date: nil, ltp: nil, context: {})
      @account_id = account_id
      @symbol = symbol
      @side = side
      @quantity = quantity
      @order_type = order_kind
      @instrument_type = instrument_type
      @option_type = option_type
      @strike_price = strike_price
      @expiry_date = expiry_date
      @ltp = ltp
      @context = context
    end

    def to_h
      {
        account_id: account_id,
        symbol: symbol,
        side: side,
        quantity: quantity,
        order_type: order_type,
        instrument_type: instrument_type,
        option_type: option_type,
        strike_price: strike_price,
        expiry_date: expiry_date,
        ltp: ltp,
        context: context
      }
    end
  end
end
