module Projections
  class PositionProjection
    class << self
      def for_account(account_id)
        ::PaperExchange::PaperPosition.where(account_id: account_id).map do |pos|
          {
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
        # Placeholder: reconcile ledger events into position snapshots
      end
    end
  end
end
