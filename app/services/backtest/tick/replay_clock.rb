module Backtest
  module Tick
    # The simulated clock for a tick or L2 replay. It only moves forward, and it
    # takes its time from the event being processed, never from the wall clock.
    class ReplayClock
      attr_reader :now

      def initialize(start_at:)
        @now = Tick.coerce_time(start_at)
      end

      def advance!(timestamp)
        candidate = Tick.coerce_time(timestamp)
        raise ArgumentError, "replay clock cannot move backwards" if candidate < now

        @now = candidate
      end
    end
  end
end
