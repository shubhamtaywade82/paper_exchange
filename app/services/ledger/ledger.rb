module Ledger
  class Ledger
    # Non-crypto cash flow (audit S5/T3.7): a sell's charges are netted
    # against its proceeds instead of producing a negative credit — when
    # charges exceed proceeds (a cheap option close), the remainder is
    # posted as a debit. A negative credit used to violate the ledger's
    # non-negative invariants and 422 the whole fill.
    def self.record_trade(account_id:, trade:)
      is_crypto_perp = trade.paper_order.respond_to?(:instrument_type) && trade.paper_order.instrument_type == "CRYPTO_PERPETUAL"
      charges = trade.respond_to?(:total_charges) ? trade.total_charges.to_f : 0.0
      debit = 0.0
      credit = 0.0

      if !is_crypto_perp && trade.side == "buy"
        debit = (trade.price * trade.quantity).to_f + charges
      elsif !is_crypto_perp && trade.side == "sell"
        net = (trade.price * trade.quantity).to_f - charges
        credit = [ net, 0.0 ].max
        debit = net.negative? ? net.abs : 0.0
      end

      entry = LedgerEntry.create!(
        account_id: account_id,
        # SCREAMING_SNAKE_CASE like every other event type (audit N2) —
        # LedgerEntry validates the format.
        event_type: "TRADE",
        payload: {
          trade_id: trade.id,
          order_id: trade.paper_order_id,
          position_id: trade.is_a?(PaperExchange::PaperTrade) ? trade.paper_position_id : nil,
          symbol: trade.paper_order&.symbol,
          quantity: trade.quantity,
          price: trade.price,
          charges: trade.charges
        },
        debit: debit,
        credit: credit,
        reference_id: trade.id.to_s,
        occurred_at: trade.traded_at
      )

      # Note: position quantity/avg_price are already updated by
      # Exchange::PositionManager.apply! before this is called (see
      # Exchange::PaperExchange#submit_order) — this entry is the immutable
      # record of the fill, not a second place that mutates the position.

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
      account.update_columns(
        unrealized_pnl: unrealized.round(8),
        realized_pnl: compute_realized_pnl(account_id).round(8),
        current_equity: compute_equity(account, unrealized).round(8)
      )
    end

    # Wallet-based so trade fees (deducted from available_balance) and
    # funding are included; margin + gross PnL overstated equity by the fees.
    # Non-crypto trades never move the wallet (their cash flow is only the
    # trade ledger entry), so that PnL is added on top; it is 0 for crypto
    # perps, whose trade entries carry no debit/credit.
    def self.compute_equity(account, unrealized)
      account.available_balance.to_f + account.locked_margin.to_f + unrealized.to_f +
        compute_trade_cash_pnl(account.account_id)
    end

    def self.compute_trade_cash_pnl(account_id)
      trade_entries = LedgerEntry.where(account_id: account_id, event_type: "TRADE")
      (trade_entries.sum(:credit) - trade_entries.sum(:debit)).to_f
    end

    # Audit S4/T3.6: no silent zero. The old bare `rescue; 0.0` masked real
    # failures (DB errors, corrupted sums) as "no realized PnL" and the
    # wrong value got cached into the account row — a money-path query that
    # fails must raise (rules.md §1), not fabricate a number.
    def self.compute_realized_pnl(account_id)
      equity_pnl = compute_trade_cash_pnl(account_id)

      pnl_entries = LedgerEntry.where(account_id: account_id, event_type: "REALIZED_PNL")
      crypto_pnl = (pnl_entries.sum(:credit) - pnl_entries.sum(:debit)).to_f

      (equity_pnl + crypto_pnl).round(8)
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
