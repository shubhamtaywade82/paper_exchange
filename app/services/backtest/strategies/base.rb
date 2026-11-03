module Backtest
  module Strategies
    class InvalidParams < StandardError; end

    # A strategy is pure. It reads one closed bar, its history, and its own
    # position, and returns order intents. It never touches the exchange.
    #
    # Intents returned from on_bar execute at the NEXT bar's open (TradingView's
    # default: orders are not processed on the bar that generated them). A
    # decision therefore can never use information from the bar it fills on.
    class Base
      # bar:        the bar that just closed
      # index:      its zero-based position in the dataset
      # history:    closed bars so far, oldest first, ending with `bar`
      # position:   the open PaperPosition for the contract, or nil
      # equity:     mark-to-market equity at this bar's close (BigDecimal)
      # next_bar_at: open time of the following bar, or nil on the last bar
      # contract:   Backtest::Contract
      StrategyContext = Struct.new(:bar, :index, :history, :position, :equity, :next_bar_at, :contract, keyword_init: true)

      attr_reader :params, :contract

      def self.key
        raise NotImplementedError
      end

      # Returns the normalized params hash that is stored on the run.
      def self.normalize_params(_raw, contract:, lot_size:)
        raise NotImplementedError
      end

      def initialize(params, contract:)
        @params = params.to_h.symbolize_keys
        @contract = contract
      end

      def on_bar(_context)
        raise NotImplementedError
      end
    end
  end
end
