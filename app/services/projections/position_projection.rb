module Projections
  class PositionProjection
    class << self
      def for_account(account_id)
        ::PaperExchange::PaperPosition.where(account_id: account_id).map do |pos|
          mark_price = MarketData::MarkPriceStore.get(pos.symbol) || pos.current_price
          {
            id: pos.id,
            account_id: pos.account_id,
            symbol: pos.symbol,
            side: pos.side,
            net_quantity: pos.quantity,
            quantity: pos.quantity,
            average_price: pos.avg_price,
            entry_price: pos.avg_price,
            current_price: mark_price,
            ltp: mark_price,
            leverage: pos.leverage,
            margin_type: pos.margin_type,
            initial_margin: pos.initial_margin,
            margin_used: pos.initial_margin,
            liquidation_price: pos.liquidation_price,
            unrealized_pnl: Ledger::Ledger.compute_pnl(pos, mark_price)
          }
        end
      end
    end
  end
end
