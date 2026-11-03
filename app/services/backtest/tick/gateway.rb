module Backtest
  module Tick
    # Executes a market order against an L2 book and books each consumed level as
    # its own fill slice through the live fill path, so the slice gets the same
    # charges, rule ids and execution_key as a live fill.
    #
    # Scope: market orders only. Limit orders, the replay loop, and position and
    # margin accounting are separate steps; this class does not change them.
    class Gateway
      LIQUIDITY_SOURCE = "book_l2".freeze

      Result = Data.define(:filled_quantity, :remaining_quantity, :slices, :trades)

      def initialize(fill_engine:)
        @fill_engine = fill_engine
      end

      def execute_market!(order:, book:, quantity:, instrument_type:)
        execution = book.execute(side: order.side, quantity: quantity)

        trades = execution.fills.map do |slice|
          _qty, _price, trade = @fill_engine.fill(
            order,
            market_snapshot: nil,
            instrument_type: instrument_type,
            quantity: slice[:quantity],
            price: slice[:price],
            liquidity_source: LIQUIDITY_SOURCE
          )
          trade
        end

        Result.new(filled_quantity: execution.filled_quantity, remaining_quantity: execution.remaining_quantity,
          slices: execution.fills, trades: trades)
      end
    end
  end
end
