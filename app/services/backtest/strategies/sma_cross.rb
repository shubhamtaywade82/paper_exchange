module Backtest
  module Strategies
    # Simple-moving-average crossover.
    #
    #   fast SMA crosses above slow SMA  -> buy at the next open
    #   fast SMA crosses below slow SMA  -> close the long (and short, if allowed)
    #
    # Each entry carries a protective stop-loss placed stop_loss_pct below
    # (or above, for a short) the signal bar's close, and an optional
    # take-profit. Shorts are disabled for option contracts: options are
    # bought, never written.
    class SmaCross < Base
      KEY = "sma_cross".freeze

      SCHEMA = Dry::Schema.Params do
        required(:fast_period).filled(:integer, gteq?: 2, lteq?: 500)
        required(:slow_period).filled(:integer, gteq?: 3, lteq?: 1000)
        required(:stop_loss_pct).filled(:decimal, gt?: 0, lt?: 100)
        optional(:take_profit_pct).maybe(:decimal, gt?: 0)
        optional(:allow_short).maybe(:bool)
      end

      def self.key
        KEY
      end

      def self.normalize_params(raw, contract:, lot_size: nil)
        result = SCHEMA.call(raw.to_h.symbolize_keys)
        raise InvalidParams, result.errors.to_h.inspect unless result.errors.empty?

        values = result.to_h
        if values[:slow_period] <= values[:fast_period]
          raise InvalidParams, "slow_period must be greater than fast_period"
        end
        if values[:allow_short] && contract.option?
          raise InvalidParams, "allow_short is not permitted on option contracts (options are bought, never written)"
        end
        if values[:allow_short] && contract.instrument_type == "EQUITY"
          raise InvalidParams, "allow_short is not permitted on cash equity (the exchange does not sell cash equity short)"
        end

        {
          fast_period: values[:fast_period],
          slow_period: values[:slow_period],
          stop_loss_pct: values[:stop_loss_pct].to_s("F"),
          take_profit_pct: values[:take_profit_pct]&.to_s("F"),
          allow_short: values.fetch(:allow_short, false) ? true : false
        }
      end

      def on_bar(context)
        history = context.history
        return [] if history.size < slow_period + 1

        current = history.size - 1
        fast_now = sma(history, fast_period, current)
        slow_now = sma(history, slow_period, current)
        fast_prev = sma(history, fast_period, current - 1)
        slow_prev = sma(history, slow_period, current - 1)

        cross_up = fast_prev <= slow_prev && fast_now > slow_now
        cross_down = fast_prev >= slow_prev && fast_now < slow_now
        close = context.bar.close
        position = context.position

        if position.nil?
          if cross_up
            [ entry("buy", close) ]
          elsif cross_down && allow_short?
            [ entry("sell", close) ]
          else
            []
          end
        elsif position.long? && cross_down
          [ { action: "close", tag: "sma_cross_exit" } ]
        elsif position.short? && cross_up
          [ { action: "close", tag: "sma_cross_exit" } ]
        else
          []
        end
      end

      private

      def fast_period
        params.fetch(:fast_period)
      end

      def slow_period
        params.fetch(:slow_period)
      end

      def allow_short?
        params[:allow_short] == true
      end

      def entry(action, close)
        stop_fraction = Parse.positive_decimal(params[:stop_loss_pct]) / 100
        take_pct = Parse.positive_decimal(params[:take_profit_pct])
        take_fraction = take_pct && take_pct / 100
        long = action == "buy"

        intent = {
          action: action,
          order_kind: "market",
          stop_loss: long ? close * (1 - stop_fraction) : close * (1 + stop_fraction),
          tag: long ? "sma_cross_long" : "sma_cross_short"
        }
        if take_fraction
          intent[:take_profit] = long ? close * (1 + take_fraction) : close * (1 - take_fraction)
        end
        intent
      end

      # Mean of the `length` closes ending at index `at`. Returns zero when
      # there is not yet enough history, so the caller's history-size guard
      # is the only place that decides whether a signal exists.
      def sma(history, length, at)
        return BigDecimal("0") if at - length + 1 < 0

        sum = BigDecimal("0")
        (at - length + 1..at).each { |i| sum += history[i].close }
        sum / length
      end
    end
  end
end
