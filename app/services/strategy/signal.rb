module Strategy
  class Signal
    attr_reader :account_id, :symbol, :side, :quantity, :order_type, :instrument_type, :option_type, :strike_price, :expiry_date, :ltp, :leverage, :context

    def initialize(account_id:, symbol:, side:, quantity:, order_kind: "market", instrument_type: "EQUITY", option_type: nil, strike_price: nil, expiry_date: nil, ltp: nil, leverage: 1, context: {})
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
      # Risk::MarginValidator reads leverage from to_h — 1 (unleveraged,
      # full-notional margin) is the conservative default for assessments.
      @leverage = leverage
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
        leverage: leverage,
        context: context
      }
    end
  end
end
