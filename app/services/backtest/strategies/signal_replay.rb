module Backtest
  module Strategies
    # Replays externally produced signals: the intents a live trading agent
    # emitted, each with the time it was decided.
    #
    # A signal stamped `ts` belongs to the bar whose window contains it:
    # bar_i.bar_at <= ts < bar_{i+1}.bar_at. It is decided at bar_i's close and
    # executes at bar_{i+1}'s open. That mapping introduces no look-ahead, and
    # it is the same timing the live exchange applies to a signal received
    # between two bars.
    #
    # Signals must fall inside the dataset's range, and must not be stamped
    # at or after the last bar, because that bar has no next open to execute on.
    # Both are rejected when the run is created.
    class SignalReplay < Base
      KEY = "signal_replay".freeze
      MAX_SIGNALS = 10_000

      SIGNAL_SCHEMA = Dry::Schema.Params do
        required(:ts).filled
        required(:action).filled(:string, included_in?: %w[buy sell close])
        optional(:order_kind).maybe(:string, included_in?: %w[market bounded stop_loss])
        optional(:quantity).maybe(:decimal, gt?: 0)
        optional(:price).maybe(:decimal, gt?: 0)
        optional(:trigger_price).maybe(:decimal, gt?: 0)
        optional(:stop_loss).maybe(:decimal, gt?: 0)
        optional(:take_profit).maybe(:decimal, gt?: 0)
        optional(:tag).maybe(:string)
      end

      def self.key
        KEY
      end

      def self.normalize_params(raw, contract:, lot_size:)
        signals = raw.to_h.symbolize_keys[:signals]
        raise InvalidParams, "signals must be an array" unless signals.is_a?(Array)
        raise InvalidParams, "at most #{MAX_SIGNALS} signals are allowed" if signals.size > MAX_SIGNALS

        errors = []
        normalized = signals.each_with_index.filter_map do |raw_signal, index|
          result = SIGNAL_SCHEMA.call(raw_signal.to_h.symbolize_keys)
          unless result.errors.empty?
            errors << "signal #{index + 1}: #{result.errors.to_h.inspect}"
            next
          end

          values = result.to_h
          ts = Parse.time(values[:ts])
          unless ts
            errors << "signal #{index + 1}: ts must be epoch seconds or ISO8601 with an offset"
            next
          end
          unless ts >= contract.first_bar_at && ts < contract.last_bar_at
            errors << "signal #{index + 1}: #{ts.iso8601} must be >= #{contract.first_bar_at.iso8601} and < #{contract.last_bar_at.iso8601} (the last bar has no next open)"
            next
          end

          begin
            IntentValidator.call(values, contract: contract, at: ts, lot_size: lot_size)
          rescue IntentValidator::Invalid => e
            errors << "signal #{index + 1}: #{e.message}"
            next
          end

          serialize_signal(values, ts)
        end

        raise InvalidParams, errors.first(20).join("; ") if errors.any?

        { signals: normalized.sort_by { |signal| signal[:ts] } }
      end

      def initialize(params, contract:)
        super
        @signals = Array(@params[:signals]).map { |s| deserialize_signal(s) }
        @cursor = 0
      end

      def on_bar(context)
        upper = context.next_bar_at
        intents = []
        while @cursor < @signals.size && (upper.nil? || @signals[@cursor][:ts] < upper)
          intents << @signals[@cursor][:intent]
          @cursor += 1
        end
        intents
      end

      def self.serialize_signal(values, ts)
        {
          ts: ts.iso8601(6),
          action: values[:action],
          order_kind: values[:order_kind],
          quantity: values[:quantity]&.to_s("F"),
          price: values[:price]&.to_s("F"),
          trigger_price: values[:trigger_price]&.to_s("F"),
          stop_loss: values[:stop_loss]&.to_s("F"),
          take_profit: values[:take_profit]&.to_s("F"),
          tag: values[:tag]
        }.compact
      end
      private_class_method :serialize_signal

      private

      # Stored signals come back from jsonb with string keys.
      def deserialize_signal(stored)
        s = stored.to_h.symbolize_keys
        {
          ts: Parse.time(s[:ts]),
          intent: {
            action: s[:action],
            order_kind: s[:order_kind],
            quantity: Parse.positive_decimal(s[:quantity]),
            price: Parse.positive_decimal(s[:price]),
            trigger_price: Parse.positive_decimal(s[:trigger_price]),
            stop_loss: Parse.positive_decimal(s[:stop_loss]),
            take_profit: Parse.positive_decimal(s[:take_profit]),
            tag: s[:tag]
          }.compact
        }
      end
    end
  end
end
