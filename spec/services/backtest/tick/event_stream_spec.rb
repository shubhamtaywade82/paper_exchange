require 'rails_helper'

# Ordering, duplicates and sequence continuity of recorded market events.
RSpec.describe 'Backtest::Tick event stream', type: :service do
  def event(symbol: 'SOLUSDT', type: 'depth_delta', at: '2026-11-03T04:00:00Z', sequence: 1, data: { 'p' => 1 })
    { symbol: symbol, type: type, timestamp: at, sequence: sequence, data: data }
  end

  describe Backtest::Tick::TickReplay do
    it 'orders by exchange timestamp, then sequence, then input position' do
      replay = described_class.new([
        event(at: '2026-11-03T04:00:01Z', sequence: 1, data: { 'n' => 'late' }),
        event(at: '2026-11-03T04:00:00Z', sequence: 2, type: 'trade', data: { 'n' => 'second' }),
        event(at: '2026-11-03T04:00:00Z', sequence: 1, type: 'trade', data: { 'n' => 'first' })
      ])

      expect(replay.map { |e| e.data['n'] }).to eq(%w[first second late])
    end

    it 'refuses an event with no sequence, rather than defaulting it to zero' do
      raw = event.except(:sequence)

      expect { described_class.new([ raw ]) }.to raise_error(Backtest::Tick::InvalidEvent, /event is missing sequence/)
    end

    it 'refuses a sequence that is not an integer' do
      expect { described_class.new([ event(sequence: 'abc') ]) }
        .to raise_error(Backtest::Tick::InvalidEvent, /integer sequence/)
    end

    it 'refuses an unknown event type' do
      expect { described_class.new([ event(type: 'quote') ]) }.to raise_error(Backtest::Tick::InvalidEvent, /unknown event type/)
    end

    it 'refuses a missing or malformed timestamp' do
      expect { described_class.new([ event(at: '2026-11-03T04:00:00') ]) }
        .to raise_error(ArgumentError, /timestamp must be a Time or an ISO-8601 value/)
    end

    it 'drops an identical repeat of an event' do
      replay = described_class.new([ event, event ])

      expect(replay.size).to eq(1)
    end

    it 'refuses two different payloads under one sequence' do
      expect { described_class.new([ event(data: { 'p' => 1 }), event(data: { 'p' => 2 }) ]) }
        .to raise_error(described_class::ConflictingEvent, /conflicting payloads/)
    end

    it 'is empty for an empty dataset' do
      expect(described_class.new([]).size).to eq(0)
    end
  end

  describe Backtest::Tick::EventLog do
    let(:log) { described_class.new }

    def parsed(sequence:, data: { 'p' => 1 }, type: 'depth_delta')
      Backtest::Tick::TickReplay::Event.new(symbol: 'SOLUSDT', type: type, timestamp: Time.utc(2026, 11, 3, 4),
        sequence: sequence, data: data)
    end

    it 'applies a contiguous sequence' do
      expect([ log.accept(parsed(sequence: 1)), log.accept(parsed(sequence: 2)) ])
        .to eq(%i[applied applied])
      expect(log.last_sequence('SOLUSDT')).to eq(2)
    end

    it 'treats a redelivered last event as a no-op, so nothing is booked twice' do
      log.accept(parsed(sequence: 1))

      expect(log.accept(parsed(sequence: 1))).to eq(:duplicate)
    end

    it 'refuses a gap, and does not synthesize the missing event' do
      log.accept(parsed(sequence: 1))

      expect { log.accept(parsed(sequence: 3)) }
        .to raise_error(Backtest::Tick::EventLog::SequenceGap, /expected sequence 2, got 3/)
      expect(log.last_sequence('SOLUSDT')).to eq(1)
    end

    it 'refuses a repeated sequence with a different payload' do
      log.accept(parsed(sequence: 1, data: { 'p' => 1 }))

      expect { log.accept(parsed(sequence: 1, data: { 'p' => 2 })) }
        .to raise_error(Backtest::Tick::EventLog::ConflictingEvent)
    end

    it 'refuses an older sequence' do
      log.accept(parsed(sequence: 1))
      log.accept(parsed(sequence: 2))

      expect { log.accept(parsed(sequence: 1, data: { 'p' => 9 })) }
        .to raise_error(Backtest::Tick::EventLog::StaleEvent)
    end

    it 'keeps one stream per symbol' do
      log.accept(parsed(sequence: 1))
      other = Backtest::Tick::TickReplay::Event.new(symbol: 'ETHUSDT', type: 'depth_delta',
        timestamp: Time.utc(2026, 11, 3, 4), sequence: 1, data: {})

      expect(log.accept(other)).to eq(:applied)
    end
  end
end
