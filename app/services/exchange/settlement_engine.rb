module Exchange
  class SettlementEngine
    def initialize(account_id:)
      @account_id = account_id
    end

    def settle(order, fill_qty:, fill_price:)
      Ledger::Ledger.record_order_placed(
        account_id: @account_id,
        order: order,
        fill_qty: fill_qty,
        fill_price: fill_price
      )
    end
  end
end
