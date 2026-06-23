module Exchange
  class FillEngine
    def initialize(slippage:)
      @slippage = slippage
    end

    def fill(order, market_snapshot:, instrument_type: "EQUITY", quantity: nil)
      qty = quantity || order.remaining_quantity
      return [:unfilled, 0] if qty <= 0

      price = @slippage.fill_price(
        market_snapshot: market_snapshot,
        side: order.side,
        instrument_type: instrument_type,
        quantity: qty
      )
      charges = BrokerageCalculator.new.calculate(
        trade_price: price,
        quantity: qty,
        side: order.side,
        symbol: order.symbol,
        instrument_type: instrument_type
      )

      trade = ::PaperExchange::PaperTrade.create!(
        paper_order: order,
        side: order.side,
        quantity: qty,
        price: price,
        charges: charges,
        total_charges: charges[:total],
        fill_type: "full",
        traded_at: Time.current
      )
      [qty, price, trade]
    end
  end
end
