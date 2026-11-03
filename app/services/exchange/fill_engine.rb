module Exchange
  class FillEngine
    LIQUIDITY_SOURCE = "top_of_book_model".freeze

    def initialize(slippage:)
      @slippage = slippage
    end

    # Books one execution slice of `order`. Each slice has an execution_key, unique
    # per order, so a slice cannot be booked twice. The sequence is the order's
    # existing fill count plus one. Callers must hold the order's account lock, as
    # the matching paths do, so two slices cannot read the same count.
    def fill(order, market_snapshot:, instrument_type: "EQUITY", quantity: nil, price: nil)
      qty = quantity || order.remaining_quantity
      return [ :unfilled, 0 ] if qty <= 0

      fill_price = price || @slippage.fill_price(
        market_snapshot: market_snapshot,
        side: order.side,
        instrument_type: instrument_type
      )
      charges = BrokerageCalculator.new.calculate(
        trade_price: fill_price,
        quantity: qty,
        side: order.side,
        symbol: order.symbol,
        instrument_type: instrument_type
      )

      trade = ::PaperExchange::PaperTrade.create!(
        paper_order: order,
        side: order.side,
        quantity: qty,
        price: fill_price,
        charges: presentation_charges(charges),
        total_charges: charges[:total],
        charge_rule_ids: charges.fetch(:rule_ids, []),
        execution_key: "#{order.id}:#{order.paper_trades.count + 1}",
        liquidity_source: LIQUIDITY_SOURCE,
        fill_type: "full",
        traded_at: Clock.now
      )
      [ qty, fill_price, trade ]
    end

    private

    # The jsonb `charges` column is a presentation copy for readers of the trade
    # record. The exact amounts are in total_charges (a decimal column) and in the
    # ledger, so this copy is the only place a float appears.
    def presentation_charges(charges)
      charges.except(:rule_ids).transform_values { |value| value.to_f }
    end
  end
end
