module Backtesting
  # Deterministic, consumable L2 snapshot. Levels are [price, quantity] pairs.
  class HistoricalOrderBook
    Execution = Struct.new(:side, :requested_quantity, :filled_quantity,
      :remaining_quantity, :average_price, :fills, :top_of_book,
      keyword_init: true) do
      def complete? = remaining_quantity <= 1e-12
    end

    attr_reader :symbol, :timestamp

    def initialize(symbol:, bids:, asks:, timestamp:)
      @symbol = normalize_symbol(symbol)
      replace!(bids: bids, asks: asks, timestamp: timestamp)
    end

    def replace!(bids:, asks:, timestamp:)
      @bids = normalize_levels(bids, :bids)
      @asks = normalize_levels(asks, :asks)
      raise ArgumentError, "both sides of the book are required" if @bids.empty? || @asks.empty?
      raise ArgumentError, "crossed book is invalid" if @bids.first[0] >= @asks.first[0]
      @timestamp = coerce_time(timestamp)
      self
    end

    def best_bid = @bids.first&.first
    def best_ask = @asks.first&.first

    # Buys walk asks; sells walk bids. Insufficient visible liquidity is a
    # partial fill, never a fabricated fill at an invented price.
    def execute(side:, quantity:, max_slippage_bps: nil)
      direction = side.to_s.downcase
      raise ArgumentError, "side must be buy or sell" unless %w[buy sell].include?(direction)
      requested = finite_number(quantity, "quantity", minimum: 0, exclusive: true)
      limit_bps = max_slippage_bps.nil? ? nil : finite_number(max_slippage_bps, "max_slippage_bps")
      levels = direction == "buy" ? @asks : @bids
      top = levels.first.first
      remaining = requested
      fills = []

      levels.each do |level|
        break if remaining <= 1e-12
        price, available = level
        break if limit_bps && adverse_move_bps(top, price, direction) > limit_bps
        amount = [remaining, available].min
        next unless amount.positive?
        fills << { price: price, quantity: amount }.freeze
        level[1] -= amount
        remaining -= amount
      end

      filled = requested - remaining
      notional = fills.sum { |fill| fill[:price] * fill[:quantity] }
      Execution.new(side: direction, requested_quantity: requested,
        filled_quantity: filled, remaining_quantity: remaining,
        average_price: filled.positive? ? notional / filled : nil,
        fills: fills.freeze, top_of_book: top).freeze
    end

    def snapshot
      { symbol: symbol, timestamp: timestamp,
        bids: @bids.map(&:dup), asks: @asks.map(&:dup) }
    end

    private

    def normalize_symbol(value)
      result = value.to_s.upcase
      raise ArgumentError, "invalid symbol" unless result.match?(/\A[A-Z0-9._-]{1,32}\z/)
      result
    end

    def normalize_levels(levels, name)
      raise ArgumentError, "#{name} must be an array" unless levels.is_a?(Array)
      normalized = levels.map do |level|
        price, quantity = if level.is_a?(Hash)
          [level[:price] || level["price"], level[:quantity] || level["quantity"]]
        else
          level
        end
        [finite_number(price, "#{name} price", minimum: 0, exclusive: true),
         finite_number(quantity, "#{name} quantity", minimum: 0, exclusive: true)]
      end
      prices = normalized.map(&:first)
      expected = name == :bids ? prices.sort.reverse : prices.sort
      raise ArgumentError, "#{name} must be price sorted" unless prices == expected
      raise ArgumentError, "#{name} contains duplicate price levels" unless prices.uniq.size == prices.size
      normalized
    end

    def coerce_time(value)
      (value.is_a?(Time) ? value : Time.iso8601(value.to_s)).utc
    rescue ArgumentError, TypeError
      raise ArgumentError, "timestamp must be a Time or ISO-8601 value"
    end

    def finite_number(value, name, minimum: 0, exclusive: false)
      number = Float(value)
      valid = number.finite? && (exclusive ? number > minimum : number >= minimum)
      raise ArgumentError, "#{name} must be finite and #{exclusive ? 'positive' : 'non-negative'}" unless valid
      number
    rescue TypeError, ArgumentError
      raise ArgumentError, "#{name} must be finite and #{exclusive ? 'positive' : 'non-negative'}"
    end

    def adverse_move_bps(reference, price, direction)
      move = direction == "buy" ? price - reference : reference - price
      [move / reference * 10_000, 0].max
    end
  end
end
