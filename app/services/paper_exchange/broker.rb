module PaperExchange
  class Broker
    attr_reader :account_id

    def initialize(account_id:)
      @account_id = account_id
      @market_data_feed = MarketDataFeed.new
      @event_bus = EventBus.new
      @slippage_engine = SlippageEngine
      @brokerage_calculator = BrokerageCalculator.new
      @pnl_engine = PnLEngine
      @margin_manager = MarginManager.new

      @position_manager = PositionManager.new(account_id: account_id)
      @fill_engine = FillEngine.new(
        brokerage_calculator: @brokerage_calculator,
        event_bus: @event_bus,
        position_manager: @position_manager
      )
      @order_manager = OrderManager.new(
        matching_engine: MatchingEngine.new(
          fill_engine: @fill_engine,
          market_data_feed: @market_data_feed,
          slippage_engine: @slippage_engine
        ),
        market_data_feed: @market_data_feed
      )
    end

    def place_order(attrs)
      @order_manager.place_order(attrs.merge(account_id: account_id))
    end

    def cancel_order(order_id)
      @order_manager.cancel_order(order_id, account_id: account_id)
    end

    def positions
      PaperExchange::PaperPosition.where(account_id: account_id)
    end

    def orders
      PaperExchange::PaperOrder.where(account_id: account_id)
    end

    def trades
      PaperExchange::PaperTrade.joins(:paper_order)
        .where(paper_exchange_paper_orders: { account_id: account_id })
    end

    def pnl
      portfolio.summary
    end

    def on(event_name, &block)
      @event_bus.subscribe(event_name, &block)
    end

    private

    def portfolio
      PortfolioManager.new(account_id, market_data_feed: @market_data_feed)
    end
  end
end
