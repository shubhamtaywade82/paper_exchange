module Backtest
  module Tick
    # Applies ordered events one stream per symbol, and refuses anything that would
    # let the book diverge from the exchange (MULTI_MARKET_SPEC §4 I6).
    #
    #   * The next event must carry the next sequence. A jump is a gap, and the
    #     interval is invalid. Nothing is synthesized to bridge it.
    #   * A repeat of the last event with the same payload is a no-op, so a
    #     redelivery books nothing twice.
    #   * A repeat with a different payload, or an older sequence, is refused.
    class EventLog
      class SequenceGap < StandardError; end
      class ConflictingEvent < StandardError; end
      class StaleEvent < StandardError; end

      APPLIED = :applied
      DUPLICATE = :duplicate

      def initialize
        @last = {}
      end

      def accept(event)
        last = @last[event.symbol]
        return store(event) if last.nil?

        if event.sequence == last.sequence
          return DUPLICATE if event.data == last.data && event.type == last.type

          raise ConflictingEvent, "#{event.symbol} sequence #{event.sequence} already applied with a different payload"
        end
        raise StaleEvent, "#{event.symbol} sequence #{event.sequence} is older than #{last.sequence}" if event.sequence < last.sequence
        raise SequenceGap, "#{event.symbol} expected sequence #{last.sequence + 1}, got #{event.sequence}" unless event.sequence == last.sequence + 1

        store(event)
      end

      def last_sequence(symbol) = @last[symbol]&.sequence

      private

      def store(event)
        @last[event.symbol] = event
        APPLIED
      end
    end
  end
end
