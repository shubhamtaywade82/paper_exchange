module Brokers
  class PaperBroker < Base
    def initialize(account_id:)
      super
      @paper_broker = PaperExchange::Broker.new(account_id: account_id)
    end

    def place_order(attrs)
      @paper_broker.place_order(attrs)
    end

    def cancel_order(order_id)
      @paper_broker.cancel_order(order_id)
    end

    def positions
      @paper_broker.positions
    end

    def orders
      @paper_broker.orders
    end

    def trades
      @paper_broker.trades
    end

    def pnl
      @paper_broker.pnl
    end

    def on(event_name, &block)
      @paper_broker.on(event_name, &block)
    end
  end
end
