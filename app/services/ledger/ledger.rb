module Ledger
  class Ledger
    def self.record_trade(account_id:, trade:)
      entry = LedgerEntry.create!(
        account_id: account_id,
        event_type: "trade",
        payload: {
          trade_id: trade.id,
          order_id: trade.paper_order_id,
          position_id: trade.is_a?(PaperExchange::PaperTrade) ? trade.paper_position_id : nil,
          symbol: trade.paper_order&.symbol,
          quantity: trade.quantity,
          price: trade.price,
          charges: trade.charges
        },
        debit: trade.side == "buy" ? (trade.price * trade.quantity + (trade.respond_to?(:total_charges) ? trade.total_charges : 0)) : 0,
        credit: trade.side == "sell" ? (trade.price * trade.quantity - (trade.respond_to?(:total_charges) ? trade.total_charges : 0)) : 0,
        reference_id: trade.id.to_s,
        occurred_at: trade.traded_at
      )

      # Note: position quantity/avg_price are already updated by
      # Exchange::PositionManager.apply! before this is called (see
      # Exchange::PaperExchange#submit_order) — do not also apply this
      # ledger entry via Projections::PositionProjection.apply_from_ledger,
      # or the fill would be double-counted onto the position.

      # Refresh the account's cached equity snapshot now that a real cash
      # event has happened. This is a low-frequency event (a fill), not a
      # price tick — it must never be driven from a mark price push (see
      # MarketData::MarkPriceStore / Api::MarkPricesController), which only
      # updates Redis and triggers in-memory liquidation checks.
      refresh_cached_equity!(account_id)

      entry
    end

    def self.refresh_cached_equity!(account_id)
      account = Account.find_by(account_id: account_id)
      return unless account

      unrealized = compute_unrealized_pnl(account_id)
      realized = compute_realized_pnl(account_id)
      account.update_columns(
        unrealized_pnl: unrealized.round(8),
        realized_pnl: realized.round(8),
        current_equity: (account.margin.to_f + unrealized + realized).round(8)
      )
    end

    def self.compute_realized_pnl(account_id)
      trade_entries = LedgerEntry.where(account_id: account_id, event_type: "trade")
      (trade_entries.sum(:credit) - trade_entries.sum(:debit)).to_f.round(8)
    rescue
      0.0
    end

    # `mark_price` defaults to the live price from MarketData::MarkPriceStore
    # (falling back to the position's last-known column value, e.g. before
    # the market data daemon has ever published a tick for the symbol) so
    # unrealized PnL reflects the current market, not the last fill.
    def self.compute_pnl(position, mark_price = nil)
      mark_price ||= MarketData::MarkPriceStore.get(position.symbol) || position.current_price
      return 0 if position.quantity.zero? || mark_price.nil?

      avg_price = position.avg_price
      return 0 if avg_price.nil?

      multiplier = position.long? ? 1 : -1
      (mark_price.to_f - avg_price.to_f) * position.quantity.to_f * multiplier
    end

    def self.compute_unrealized_pnl(account_id)
      positions = ::PaperExchange::PaperPosition.where(account_id: account_id)
      positions.sum { |p| Ledger.compute_pnl(p) }
    end
  end
end
