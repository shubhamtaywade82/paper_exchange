module Risk
  class PositionLimitValidator
    MAX_POSITIONS = (ENV.fetch("PAPER_EXCHANGE_MAX_POSITIONS", "10").to_i)

    def evaluate(account_id, signal)
      return :passed if MAX_POSITIONS <= 0

      # A closed position stays as a quantity 0 row, so only non-zero rows are real exposure.
      count = PaperExchange::PaperPosition.where(account_id: account_id).where.not(quantity: 0).count
      count >= MAX_POSITIONS ? :POSITION_LIMIT_REJECTED : :passed
    end
  end
end
