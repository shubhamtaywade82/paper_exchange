module Exchange
  class SettlementEngine
    def initialize(account_id:)
      @account_id = account_id
    end

    def settle(order, fill_qty:, fill_price:)
      # Ledger and projections are already updated by the fill/trade path.
    end
  end
end
