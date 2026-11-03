module Backtest
  # Mark-to-market equity in BigDecimal: available + locked margin + the
  # unrealized P&L of open positions at the session's marks.
  #
  # Ledger::Ledger.compute_equity works in Float. A backtest equity curve is
  # compared across runs, so it must not accumulate float error. The same
  # formula is computed here in BigDecimal.
  module Equity
    module_function

    def now(account_id:, symbol:)
      account = Account.find_by!(account_id: account_id)
      mark = Session.current&.mark(symbol)

      unrealized = ::PaperExchange::PaperPosition
        .where(account_id: account_id)
        .where.not(quantity: 0)
        .to_a
        .sum(BigDecimal("0")) { |position| position_pnl(position, mark) }

      account.available_balance + account.locked_margin + unrealized
    end

    # With no mark yet, the position is valued at cost (zero unrealized P&L).
    def position_pnl(position, mark)
      return BigDecimal("0") if mark.nil?

      direction = position.long? ? 1 : -1
      (BigDecimal(mark.to_s) - position.avg_price) * position.quantity * direction
    end
  end
end
