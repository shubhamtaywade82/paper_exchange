module Risk
  class MaxDrawdownValidator
    # P1-1 fix: the old formula compared current_equity against INITIAL
    # margin, not the historical peak. An account that grew from 100k to
    # 200k and then fell to 150k reported 0% drawdown (still above starting
    # capital) when the real drawdown from peak is 25% — genuine drawdowns
    # from a peak went undetected and could let oversized risk through.
    #
    # This validator now:
    #   1. Computes LIVE equity (available + locked + unrealized from current
    #      mark prices) rather than relying on the cached current_equity
    #      column, which is only refreshed on fills — a large unrealized loss
    #      between fills was invisible to the gate.
    #   2. Compares against the persisted high-water mark
    #      (account.max_equity_achieved), which PortfolioProjection.summary
    #      updates lazily on read.
    MAX_DD = ENV.fetch("PAPER_EXCHANGE_MAX_DRAWDOWN") { ENV.fetch("PAPER_EXCHANGE_MAX_DD", "0.20") }.to_f

    def evaluate(account_id, signal)
      account = Account.find_by(account_id: account_id)
      return :passed unless account

      # Live equity from current marks — not the stale cached column.
      unrealized = Ledger::Ledger.compute_unrealized_pnl(account_id)
      equity = Ledger::Ledger.compute_equity(account, unrealized)

      # P1-1: drawdown from the persisted high-water mark, not initial margin.
      # max_equity_achieved is backfilled to margin on migration, so accounts
      # that never grew use the old baseline; accounts that grew track their
      # real peak.
      peak = [ account.max_equity_achieved.to_f, account.margin.to_f ].max
      return :passed if peak <= 0

      dd = (peak - equity) / peak
      dd <= MAX_DD ? :passed : :MAX_DD_REJECTED
    end
  end
end
