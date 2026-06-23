module Domains
  module Risk
    class PositionLimitValidator
      MAX_POSITIONS = (ENV.fetch("PAPER_EXCHANGE_MAX_POSITIONS", "10").to_i)
      MAX_SYMBOL_QTY = (ENV.fetch("PAPER_EXCHANGE_MAX_SYMBOL_QTY", "100").to_i)

      def evaluate(account_id, signal)
        positions = Projections::PositionProjection.for_account(account_id)
        symbol_positions = positions.select { |p| p[:symbol] == signal.to_h[:symbol] }
        return [:LPP_REJECTED, self] if positions.size >= MAX_POSITIONS
        return [:LPP_REJECTED, self] if symbol_positions.sum { |p| p[:net_quantity] } >= MAX_SYMBOL_QTY

        [:passed, self]
      end
    end
  end
end
