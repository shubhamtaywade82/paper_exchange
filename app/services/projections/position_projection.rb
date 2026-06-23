module Projections
  class PositionProjection
    class << self
      def for_account(account_id)
        ::PaperExchange::PaperPosition.where(account_id: account_id).map do |pos|
          {
            id: pos.id,
            account_id: pos.account_id,
            symbol: pos.symbol,
            side: pos.side,
            net_quantity: pos.quantity,
            average_price: pos.avg_price,
            current_price: pos.current_price,
            ltp: pos.current_price,
            unrealized_pnl: Ledger::Ledger.compute_pnl(pos, pos.current_price || 0)
          }
        end
      end

      def apply_from_ledger(ledger_entry)
        return unless ledger_entry.payload

        trade_id = ledger_entry.payload["trade_id"] || ledger_entry.payload[:trade_id]
        trade = ::PaperExchange::PaperTrade.find_by(id: trade_id)
        return unless trade

        order = trade.paper_order
        position = ::PaperExchange::PaperPosition.find_or_initialize_by(
          account_id: ledger_entry.account_id,
          symbol: order.symbol,
          side: order.side == "buy" ? "long" : "short"
        )
        position.instrument_type = order.instrument_type
        position.option_type = order.option_type
        position.strike_price = order.strike_price
        position.expiry_date = order.expiry_date

        delta = order.side == "buy" ? trade.quantity : -trade.quantity
        position.quantity = (position.quantity || 0) + delta

        if position.quantity.zero?
          position.current_price = 0
          position.avg_price = 0
        elsif delta > 0
          total = (position.avg_price || 0) * (position.quantity - delta) + (trade.price * delta)
          position.avg_price = total / position.quantity if position.quantity > 0
        end

        position.current_price = trade.price
        position.save!
      end
    end
  end
end
