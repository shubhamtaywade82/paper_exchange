module Backtest
  module Tick
    # An L2 book for one symbol, rebuilt from a snapshot and then kept current by
    # depth deltas. Prices and quantities are BigDecimal.
    #
    # A buy walks asks from the best price upward, and a sell walks bids downward.
    # Depth is consumed, so a later order sees only what is left. Insufficient
    # depth gives a partial execution, with the unfilled remainder reported. A
    # price is never invented to fill it.
    class HistoricalOrderBook
      class InvalidBook < ArgumentError; end
      class CrossedBook < InvalidBook; end

      Execution = Data.define(:side, :requested_quantity, :filled_quantity, :remaining_quantity,
        :average_price, :fills, :top_of_book) do
        def complete? = remaining_quantity.zero?
      end

      attr_reader :symbol, :timestamp

      def initialize(symbol:, bids:, asks:, timestamp:)
        @symbol = normalize_symbol(symbol)
        @bids = build_side(bids, :bids)
        @asks = build_side(asks, :asks)
        @timestamp = Tick.coerce_time(timestamp)
        refuse_crossed!(@bids, @asks)
      end

      def best_bid = levels(:bids).first
      def best_ask = levels(:asks).first

      # A depth delta sets the quantity at one price, and zero removes the level.
      # The change is applied to a copy, so a delta that would cross the book is
      # refused and leaves the book as it was.
      def apply_delta(side:, price:, quantity:, timestamp:)
        name = side.to_sym
        raise InvalidBook, "side must be bids or asks" unless %i[bids asks].include?(name)

        level_price = Tick.decimal(price, "#{name} price")
        level_quantity = Tick.decimal(quantity, "#{name} quantity", allow_zero: true)
        bids = @bids.dup
        asks = @asks.dup
        target = name == :bids ? bids : asks
        if level_quantity.zero?
          target.delete(level_price)
        else
          target[level_price] = level_quantity
        end
        refuse_crossed!(bids, asks)

        @bids = bids
        @asks = asks
        @timestamp = Tick.coerce_time(timestamp)
        self
      end

      # Consumes depth for one order and returns what it did. The book changes:
      # the consumed quantity is removed from each level it touched.
      def execute(side:, quantity:, max_slippage_bps: nil)
        direction = side.to_s.downcase
        raise ArgumentError, "side must be buy or sell" unless %w[buy sell].include?(direction)

        requested = Tick.decimal(quantity, "quantity")
        limit = max_slippage_bps.nil? ? nil : Tick.decimal(max_slippage_bps, "max_slippage_bps", allow_zero: true)
        book_side = direction == "buy" ? :asks : :bids
        top = levels(book_side).first
        remaining = requested
        fills = []

        levels(book_side).each do |price|
          break if remaining.zero?
          break if limit && adverse_bps(top, price, direction) > limit

          target = book_side == :asks ? @asks : @bids
          available = target.fetch(price)
          amount = [ remaining, available ].min
          fills << { price: price, quantity: amount }.freeze
          remaining -= amount
          available -= amount
          available.zero? ? target.delete(price) : target[price] = available
        end

        filled = requested - remaining
        notional = fills.sum(BigDecimal("0")) { |fill| fill[:price] * fill[:quantity] }
        Execution.new(side: direction, requested_quantity: requested, filled_quantity: filled,
          remaining_quantity: remaining, average_price: filled.positive? ? notional.div(filled, 18) : nil,
          fills: fills.freeze, top_of_book: top)
      end

      def depth(side)
        levels(side.to_sym).map { |price| [ price, (side.to_sym == :asks ? @asks : @bids).fetch(price) ] }
      end

      private

      # Bids sort high to low, asks low to high, so the best level is first.
      def levels(side)
        prices = side == :asks ? @asks.keys : @bids.keys
        side == :asks ? prices.sort : prices.sort.reverse
      end

      def build_side(levels, name)
        raise InvalidBook, "#{name} must be an array" unless levels.is_a?(Array)

        book = {}
        levels.each do |level|
          price, quantity = level.is_a?(Hash) ? [ level[:price] || level["price"], level[:quantity] || level["quantity"] ] : level
          level_price = Tick.decimal(price, "#{name} price")
          raise InvalidBook, "#{name} contains duplicate price levels" if book.key?(level_price)

          book[level_price] = Tick.decimal(quantity, "#{name} quantity")
        end
        book
      end

      def refuse_crossed!(bids, asks)
        return if bids.empty? || asks.empty?

        raise CrossedBook, "crossed book is invalid" if bids.keys.max >= asks.keys.min
      end

      def adverse_bps(reference, price, direction)
        move = direction == "buy" ? price - reference : reference - price
        [ move / reference * 10_000, BigDecimal("0") ].max
      end

      def normalize_symbol(value)
        result = value.to_s.upcase
        raise InvalidBook, "invalid symbol" unless result.match?(/\A[A-Z0-9._-]{1,32}\z/)

        result
      end
    end
  end
end
