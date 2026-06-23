module PaperExchange
  class SlippageEngine
    DEFAULT_IMPACT_FACTOR = 0.0002

    class << self
      def calculate(price:, quantity: 1, side: :buy, impact_factor: DEFAULT_IMPACT_FACTOR)
        impact = quantity * impact_factor
        side == :buy ? price + impact : price - impact
      end

      def price_for_buy(ask:, quantity: 1)
        calculate(price: ask, quantity: quantity, side: :buy)
      end

      def price_for_sell(bid:, quantity: 1)
        calculate(price: bid, quantity: quantity, side: :sell)
      end

      def fill_for_option(bid:, ask:, buy:, quantity: 1)
        base_price = buy ? ask : bid
        calculate(price: base_price, quantity: quantity, side: buy ? :buy : :sell, impact_factor: 0.00005)
      end
    end
  end
end
