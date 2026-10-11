module Ledger
  class Ledger
    # Records one fill's cash flow as an immutable TRADE ledger entry AND
    # posts the wallet movements (fees, realized PnL) that actually move
    # Account.available_balance. For crypto perps the trade entry itself
    # carries no debit/credit — the wallet movements happen via the separate
    # MarginLedger calls below. For non-crypto instruments the TRADE entry
    # is also an audit record only (P0-1 fix): the purchase cost is already
    # captured in locked_margin via MarginEngine.sync_position!, so adding
    # it again as a debit against available_balance would double-count.
    # Realized PnL on a closing trade is posted via credit_realized_pnl! /
    # deduct_fee! so the wallet reflects the actual cash movement.
    #
    # Audit S5/T3.7: a sell's charges are netted against its proceeds
    # instead of producing a negative credit — when charges exceed proceeds
    # (a cheap option close), the remainder is posted as a debit.
    def self.record_trade(account_id:, trade:, realized_pnl: nil)
      is_crypto_perp = trade.paper_order.respond_to?(:instrument_type) && trade.paper_order.instrument_type == "CRYPTO_PERPETUAL"
      charges = trade.respond_to?(:total_charges) ? trade.total_charges.to_f : 0.0

      # The TRADE entry is the immutable audit record of the fill. Its
      # debit/credit fields capture the gross cash flow direction for
      # reconciliation; the actual wallet movements happen via MarginLedger
      # so available_balance/locked_margin stay consistent with the
      # position's initial_margin (P0-1).
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

      # Post the wallet movements for non-crypto trades (crypto perps
      # already had their fees and realized PnL posted in submit_order).
      # For non-crypto: realized PnL on a closing fill is posted via
      # MarginLedger so available_balance reflects the actual cash gain/loss
      # and locked_margin releases the position's cost correctly (P0-1).
      unless is_crypto_perp
        # P0-1: realized PnL on a closing fill is posted via MarginLedger so
        # available_balance reflects the actual cash gain/loss. Read from
        # the explicit param first (caller has the in-memory instance), then
        # fall back to the trade's position association.
        pnl = realized_pnl
        if pnl.nil?
          position = trade.is_a?(PaperExchange::PaperTrade) ? trade.paper_position : nil
          pnl = position&.last_realized_pnl
        end

        if pnl && !pnl.zero?
          MarginLedger.credit_realized_pnl!(
            account_id: account_id,
            amount: pnl,
            event_type: "REALIZED_PNL",
            reference_id: trade.id.to_s,
            payload: { trade_id: trade.id, symbol: trade.paper_order&.symbol, reason: "trade_realized_pnl" }
          )
        end

        if charges > 0
          MarginLedger.deduct_fee!(
            account_id: account_id,
            amount: charges,
            event_type: "FEE",
            reference_id: trade.id.to_s,
            payload: { trade_id: trade.id, symbol: trade.paper_order&.symbol, reason: "trade_fee" }
          )
        end
      end

      # Refresh the account's cached equity snapshot now that a real cash
      # event has happened. This is a low-frequency event (a fill), not a
      # price tick — it must never be driven from a mark price push.
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

    # Equity = available cash + locked margin (which includes the full
    # notional of all open positions, P0-1) + unrealized PnL.
    #
    # The old formula added `trade_cash_pnl` (the net of TRADE debits/credits)
    # on top, which double-counted the purchase cost: available_balance was
    # not reduced by the purchase (the lock-then-release dance netted to
    # zero for the order's own margin), AND the TRADE debit subtracted the
    # cost again. With the P0-1 fix, the purchase cost stays in locked_margin
    # via MarginEngine.sync_position!, so trade_cash_pnl is no longer needed
    # in the equity formula — it was the source of the 80% phantom drawdown.
    def self.compute_equity(account, unrealized)
      account.available_balance.to_f + account.locked_margin.to_f + unrealized.to_f
    end

    # Realized PnL comes from the REALIZED_PNL ledger stream — posted by
    # MarginLedger.credit_realized_pnl! on every closing fill (both crypto
    # and non-crypto, P0-1). The TRADE stream's debits/credits are no longer
    # part of this calculation because they would double-count the position
    # cost that is already in locked_margin.
    def self.compute_realized_pnl(account_id)
      pnl_entries = LedgerEntry.where(account_id: account_id, event_type: "REALIZED_PNL")
      (pnl_entries.sum(:credit) - pnl_entries.sum(:debit)).to_f.round(8)
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
