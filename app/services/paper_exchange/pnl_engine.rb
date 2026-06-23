module PaperExchange
  class PnLEngine
    class << self
      def unrealized_pnl(position, current_price)
        return 0 if position.quantity.zero? || current_price.nil?

        multiplier = position.long? ? 1 : -1
        (current_price - position.avg_price) * position.quantity * multiplier
      end

      def realized_pnl(position)
        position.realized_pnl || 0
      end

      def total_pnl(position, current_price)
        realized_pnl(position) + unrealized_pnl(position, current_price)
      end
    end
  end
end
