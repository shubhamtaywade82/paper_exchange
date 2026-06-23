module Exchange
  class PositionManager
    def self.apply!(account_id:, symbol:, side:, quantity:, avg_price:)
      position = ::PaperExchange::PaperPosition.find_or_initialize_by(
        account_id: account_id,
        symbol: symbol,
        side: side
      )
      position.quantity ||= 0
      position.avg_price ||= 0

      position.quantity += quantity
      if quantity > 0
        total_cost = (position.avg_price * (position.quantity - quantity)) + (avg_price * quantity)
        position.avg_price = total_cost / position.quantity if position.quantity > 0
      end

      position.save!
      position
    end
  end
end
