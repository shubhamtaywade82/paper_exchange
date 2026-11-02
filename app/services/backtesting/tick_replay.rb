module Backtesting
  # Stable chronological replay: timestamp, exchange sequence, input index.
  class TickReplay
    include Enumerable

    def initialize(events)
      @events = Array(events).each_with_index.map do |event, index|
        timestamp = value(event, :timestamp)
        sequence = optional_value(event, :sequence)
        time = (timestamp.is_a?(Time) ? timestamp : Time.iso8601(timestamp.to_s)).utc
        seq = sequence.nil? ? 0 : Integer(sequence)
        [time, seq, index, event]
      rescue ArgumentError, TypeError, KeyError
        raise ArgumentError, "every replay event needs a valid timestamp and integer sequence"
      end.sort_by { |time, sequence, index, _event| [time, sequence, index] }
    end

    def each
      return enum_for(:each) unless block_given?
      @events.each { |time, sequence, _index, event| yield event, time, sequence }
    end

    def size = @events.size

    private

    def value(event, key)
      return event.public_send(key) if event.respond_to?(key)
      return event.fetch(key) if event.key?(key)
      event.fetch(key.to_s)
    end

    def optional_value(event, key)
      return event.public_send(key) if event.respond_to?(key)
      return event[key] if event.respond_to?(:key?) && event.key?(key)
      return event[key.to_s] if event.respond_to?(:key?) && event.key?(key.to_s)
      nil
    end
  end
end
