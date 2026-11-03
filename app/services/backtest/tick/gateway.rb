module Backtest
  module Tick
    # Executes a market order against an L2 book. Each consumed level is booked as
    # its own fill slice through the live fill path, so every slice gets the same
    # charges, rule ids and execution_key as a live fill. The order is then settled
    # from the result: fully filled, or cancelled with its executed quantity kept
    # and the remainder explained (insufficient_depth).
    #
    # Scope: market orders only. Limit orders and the replay loop are separate
    # steps; this class does not change them.
    class Gateway
      LIQUIDITY_SOURCE = "book_l2".freeze
      INSUFFICIENT_DEPTH = "insufficient_depth".freeze

      Result = Data.define(:status, :filled_quantity, :remaining_quantity, :slices, :trades)

      def initialize(fill_engine:)
        @fill_engine = fill_engine
      end

      def execute_market!(order:, book:, quantity:, instrument_type:)
        raise ArgumentError, "a market order is executed for its full quantity" unless quantity == order.quantity
        raise ArgumentError, "order must be open to execute, not #{order.status}" unless order.open? || order.partially_filled?

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

        status = settle!(order, execution)
        Result.new(status: status, filled_quantity: execution.filled_quantity,
          remaining_quantity: execution.remaining_quantity, slices: execution.fills, trades: trades)
      end

      private

      def settle!(order, execution)
        order.update!(filled_quantity: execution.filled_quantity, avg_fill_price: execution.average_price)
        if execution.complete?
          order.filled!
          :filled
        else
          order.cancel!(reason: INSUFFICIENT_DEPTH)
          :cancelled
        end
      end
    end
  end
end
