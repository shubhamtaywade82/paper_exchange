module Backtest
  module Tick
    # Orders recorded market events deterministically: exchange timestamp, then
    # exchange sequence, then input position. A sequence is required, because a
    # defaulted sequence would make ties depend on input order.
    #
    # An identical repeat of an event is dropped. A different payload under the
    # same (symbol, type, sequence) is a conflict and is refused.
    class TickReplay
      class ConflictingEvent < InvalidEvent; end

      TYPES = %w[snapshot depth_delta trade mark funding].freeze
      Event = Data.define(:symbol, :type, :timestamp, :sequence, :data)

      include Enumerable

      def initialize(events)
        entries = Array(events).each_with_index.map { |raw, index| [ build(raw), index ] }
        @events = dedupe(entries).sort_by { |event, index| [ event.timestamp, event.sequence, index ] }.map(&:first).freeze
      end

      def each(&block)
        return enum_for(:each) unless block

        @events.each(&block)
      end

      def size = @events.size

      private

      def build(raw)
        symbol = fetch(raw, :symbol).to_s.upcase
        raise InvalidEvent, "every event needs a symbol" if symbol.empty?

        type = fetch(raw, :type).to_s
        raise InvalidEvent, "unknown event type #{type.inspect}" unless TYPES.include?(type)

        timestamp = Tick.coerce_time(fetch(raw, :timestamp))
        sequence = Integer(fetch(raw, :sequence), exception: false)
        raise InvalidEvent, "every event needs an integer sequence, not a default" if sequence.nil? || sequence.negative?

        Event.new(symbol: symbol, type: type, timestamp: timestamp, sequence: sequence, data: fetch(raw, :data) || {})
      end

      def dedupe(entries)
        seen = {}
        entries.each_with_object([]) do |(event, index), kept|
          key = [ event.symbol, event.type, event.sequence ]
          if seen.key?(key)
            raise ConflictingEvent, "conflicting payloads for #{key.inspect}" unless seen[key] == event.data

            next
          end
          seen[key] = event.data
          kept << [ event, index ]
        end
      end

      def fetch(raw, key)
        return raw.public_send(key) if raw.respond_to?(key)
        return raw.fetch(key) if raw.key?(key)
        return raw.fetch(key.to_s) if raw.key?(key.to_s)

        raise InvalidEvent, "event is missing #{key}"
      end
    end
  end
end
