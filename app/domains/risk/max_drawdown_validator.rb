module Domains
  module Risk
    class MaxDrawdownValidator
      MAX_DD = (ENV.fetch("PAPER_EXCHANGE_MAX_DD", "0.10").to_f)

      def evaluate(account_id, signal)
        summary = Domains::Projections::PortfolioProjection.summary(account_id)
        equity = summary[:equity] || ENV.fetch("PAPER_EXCHANGE_MARGIN", "100000").to_f
        max_equity = summary[:max_equity] || equity
        return [:passed, self] if max_equity <= 0

        dd = (max_equity - equity) / max_equity
        dd <= MAX_DD ? [:passed, self] : [:MAX_DD_REJECTED, self]
      end
    end
  end
end
