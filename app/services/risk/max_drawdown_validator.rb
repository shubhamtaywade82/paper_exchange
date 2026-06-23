module Risk
  class MaxDrawdownValidator
    MAX_DD = (ENV.fetch("PAPER_EXCHANGE_MAX_DD", "0.10").to_f)

    def evaluate(account_id, signal)
      account = Account.find_by(account_id: account_id)
      return [:passed, self] unless account

      equity = account.current_equity
      max_equity = [equity, account.margin].max
      return [:passed, self] if max_equity <= 0

      dd = (max_equity - equity) / max_equity
      dd <= MAX_DD ? [:passed, self] : [:MAX_DD_REJECTED, self]
    end
  end
end
