module Risk
  class PositionLimitValidator
    MAX_POSITIONS = (ENV.fetch("PAPER_EXCHANGE_MAX_POSITIONS", "10").to_i)

    def evaluate(account_id, signal)
      return [:passed, self] if MAX_POSITIONS <= 0

      count = PaperExchange::PaperPosition.where(account_id: account_id).count
      count >= MAX_POSITIONS ? [:LPP_REJECTED, self] : [:passed, self]
    end
  end
end
