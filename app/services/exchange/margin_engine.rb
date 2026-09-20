module Exchange
  # Keeps an account's `locked_margin` in sync with the initial margin
  # actually required by one of its open leveraged-futures positions, and
  # (re)computes the position's liquidation price. Invoked after every fill,
  # once PositionManager has applied the trade.
  #
  # Only positions opened with leverage > 1 participate in this wallet-margin
  # model — unleveraged (leverage 1, the default for equity/F&O) positions
  # keep the pre-existing behavior of settling entirely through the trade's
  # cash flow in Ledger::Ledger, with no locked_margin/liquidation_price of
  # their own. This preserves the existing ratio-based equity margin model
  # (Risk::MarginValidator) instead of double-charging equity trades against
  # this futures-only wallet split.
  class MarginEngine
    def self.sync_position!(position, account_id:)
      flat = position.quantity.to_f.zero?
      leveraged = !flat && position.leverage.to_i > 1

      required = leveraged ? BigDecimal(
        LiquidationCalculator.initial_margin(notional: position.notional_value, leverage: position.leverage).to_s
      ) : BigDecimal("0")

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
