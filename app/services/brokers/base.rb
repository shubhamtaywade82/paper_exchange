module Brokers
  class Base
    def initialize(account_id:)
      @account_id = account_id
    end

    def place_order(attrs)
      raise NotImplementedError
    end

    def cancel_order(order_id)
      raise NotImplementedError
    end

    def positions
      raise NotImplementedError
    end

    def orders
      raise NotImplementedError
    end

    def trades
      raise NotImplementedError
    end

    def pnl
      raise NotImplementedError
    end

    def on(event_name, &block); end
  end
end
