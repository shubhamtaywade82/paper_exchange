module Ledger
  class Ledger
    def self.record_order_placed(account_id:, order:, fill_qty:, fill_price:)
      entry = LedgerEntry.create!(
        account_id: account_id,
        event_type: "ORDER_PLACED",
        payload: {
          order_id: order.id,
          symbol: order.symbol,
          side: order.side,
          quantity: fill_qty,
          price: fill_price
        },
        debit: order.side == "buy" ? fill_price * fill_qty : 0,
        credit: order.side == "sell" ? fill_price * fill_qty : 0,
        reference_id: order.id.to_s,
        occurred_at: Time.current
      )
      account = Account.find_by!(account_id: account_id)
      account.update!(
        unrealized_pnl: compute_unrealized_pnl(account_id),
        realized_pnl: compute_realized_pnl(account_id),
        current_equity: account.balance_after
      )
      Projections::PositionProjection.apply_from_ledger(entry)
      Projections::PortfolioProjection.rebuild_for_account(account_id)
      entry
    end

    def self.record_trade(account_id:, trade:)
      entry = LedgerEntry.create!(
        account_id: account_id,
        event_type: "TRADE_EXECUTED",
        payload: {
          trade_id: trade.id,
          order_id: trade.paper_order_id,
          position_id: trade.paper_position_id,
          symbol: trade.paper_order&.symbol,
          quantity: trade.quantity,
          price: trade.price,
          charges: trade.charges
        },
        debit: trade.side == "buy" ? trade.price * trade.quantity : 0,
        credit: trade.side == "sell" ? trade.price * trade.quantity : 0,
        reference_id: trade.id.to_s,
        occurred_at: trade.traded_at
      )
      account = Account.find_by!(account_id: account_id)
      account.update!(
        unrealized_pnl: compute_unrealized_pnl(account_id),
        realized_pnl: compute_realized_pnl(account_id),
        current_equity: account.balance_after
      )
      entry
    end

    def self.compute_pnl(position, current_price)
      return 0 if position.quantity.zero? || current_price.nil?
      multiplier = position.long? ? 1 : -1
      (current_price - position.avg_price) * position.quantity * multiplier
    end

    def self.compute_unrealized_pnl(account_id)
      positions = ::PaperExchange::PaperPosition.where(account_id: account_id)
      positions.sum { |p| Ledger.compute_pnl(p, p.current_price || 0) }
    end

    def self.compute_realized_pnl(account_id)
      ::PaperExchange::PaperTrade.joins(:paper_position)
        .where(paper_exchange_positions: { account_id: account_id })
        .sum("paper_trades.quantity * (paper_trades.price - paper_exchange_positions.avg_price) * CASE WHEN paper_trades.side = 'buy' THEN 1 ELSE -1 END")
    end
  end
end
