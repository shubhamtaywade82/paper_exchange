module Risk
  class MaxDrawdownValidator
    # Audit S9/T3.3: the documented variable name is
    # PAPER_EXCHANGE_MAX_DRAWDOWN (README + .env.example, default 0.20);
    # the code used to read PAPER_EXCHANGE_MAX_DD with default 0.10, so
    # operators configuring the documented knob changed nothing. The
    # historical spelling is still honored if explicitly set.
    MAX_DD = ENV.fetch("PAPER_EXCHANGE_MAX_DRAWDOWN") { ENV.fetch("PAPER_EXCHANGE_MAX_DD", "0.20") }.to_f

    def evaluate(account_id, signal)
      account = Account.find_by(account_id: account_id)
      return :passed unless account

      equity = account.current_equity
      max_equity = [ equity, account.margin ].max
      return :passed if max_equity <= 0

      dd = (max_equity - equity) / max_equity
      dd <= MAX_DD ? :passed : :MAX_DD_REJECTED
    end
  end
end
