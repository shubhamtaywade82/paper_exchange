module Exchange
  # Keeps an account's `locked_margin` in sync with the initial margin
  # actually required by one of its open positions, and (re)computes a
  # leveraged position's liquidation price. Invoked after every fill,
  # once PositionManager has applied the trade.
  #
  # Contract (audit S6): callers must pass the LOCKED position instance
  # returned by PositionManager.apply! — the one whose in-memory attributes
  # reflect the fill just applied under the row lock. Computing `delta`
  # against a stale instance (re-read without the lock) is what produced
  # last-writer-wins `initial_margin` values under concurrent fills.
  #
  # Accounting model (P0-1 fix): ALL open positions — leveraged crypto
  # perps AND unleveraged cash instruments (equity, F&O) — lock their
  # required initial margin against the account's wallet. For crypto perps
  # that is notional / leverage; for unleveraged instruments it is the
  # FULL notional (the entire purchase cost). This makes the equity
  # formula `available_balance + locked_margin + unrealized_pnl` correct
  # for both models: the capital tied up in holdings is always in
  # locked_margin, available_balance is always free cash, and unrealized
  # PnL captures the mark-to-market gain/loss on top. Previously
  # unleveraged positions locked zero margin and the TRADE ledger debit
  # was double-counted against available_balance in the equity formula.
  class MarginEngine
    def self.sync_position!(position, account_id:)
      flat = position.quantity.to_f.zero?
      leveraged = !flat && position.leverage.to_i > 1

      notional = (position.avg_price.to_f * position.quantity.to_f).abs
      required = if flat
        BigDecimal("0")
      elsif leveraged
        BigDecimal(LiquidationCalculator.initial_margin(notional: notional, leverage: position.leverage).to_s)
      else
        # P0-1: unleveraged instruments lock full notional as position
        # margin — the purchase cost stays reserved in the wallet so
        # available_balance correctly reflects free cash and equity =
        # available + locked + unrealized is internally consistent.
        BigDecimal(notional.to_s)
      end

      delta = required - position.initial_margin.to_d
      reference_id = position.id.to_s
      payload = { position_id: position.id, symbol: position.symbol, reason: "position_margin_sync" }

      if delta.positive?
        Ledger::MarginLedger.lock_margin!(account_id: account_id, amount: delta, reference_id: reference_id, payload: payload)
      elsif delta.negative?
        Ledger::MarginLedger.unlock_margin!(account_id: account_id, amount: delta.abs, reference_id: reference_id, payload: payload)
      end

      liquidation_price = leveraged ? LiquidationCalculator.liquidation_price(
        entry_price: position.avg_price,
        leverage: position.leverage,
        side: position.side
      ) : nil

      position.update_columns(initial_margin: required, liquidation_price: liquidation_price)
      position
    end
  end
end
