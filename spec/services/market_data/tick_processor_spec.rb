require 'rails_helper'

RSpec.describe MarketData::TickProcessor, type: :service do
  # Minimal in-memory stand-in for the two Redis stream commands used
  # (redis 6.0 signatures: xadd(key, entry, id:, maxlen:, approximate:)
  # and xrevrange(key, range_end = '+', start = '-', count:)). The CI
  # environment has no Redis server — the controller specs stub this
  # class entirely; these specs pin the stream semantics (ordering,
  # exclusive cursor, symbol filter, nil-omission) against the fake.
  class FakeStreamRedis
    attr_reader :entries

    def initialize
      @entries = []
      @seq = 0
    end

    def xadd(_key, entry, id: "*", maxlen: nil, approximate: nil)
      @seq += 1
      id = "#{(Time.now.to_f * 1000).to_i}-#{@seq}"
      @entries << [ id, entry.transform_keys(&:to_s) ]
      id
    end

    def xrevrange(_key, range_end = "+", start = "-", count: nil)
      newest_first = @entries.reverse
      if range_end.to_s.start_with?("(")
        boundary = range_end.to_s[1..]
        index = newest_first.index { |id, _data| id == boundary }
        newest_first = index ? newest_first[(index + 1)..] : []
      end
      count ? newest_first.first(count) : newest_first
    end
  end

  class UnavailableRedis
    def xadd(*)
      raise Redis::ConnectionError, "connection refused"
    end

    def xrevrange(*)
      raise Redis::ConnectionError, "connection refused"
    end
  end

  def tick(symbol: "BTCUSDT", price: 65_000.0)
    MarketData::MarketEvent.new(
      symbol: symbol, price: price, bid: price - 1, ask: price + 1,
      quantity: 0.5, timestamp: 1.minute.ago, source: "test"
    )
  end

  before { described_class.instance_variable_set(:@redis, nil) }

  describe '.enqueue' do
    it 'appends the tick with string values and returns the stream id' do
      fake = FakeStreamRedis.new
      allow(described_class).to receive(:redis).and_return(fake)

      id = described_class.enqueue(tick)

      expect(id).to match(/\A\d+-\d+\z/)
      stored = fake.entries.last.last
      expect(stored["symbol"]).to eq("BTCUSDT")
      expect(stored["price"]).to eq("65000.0")
      expect(stored["timestamp"]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it 'omits nil fields instead of storing empty strings' do
      fake = FakeStreamRedis.new
      allow(described_class).to receive(:redis).and_return(fake)

      described_class.enqueue(MarketData::MarketEvent.new(symbol: "BTCUSDT", timestamp: Time.current))

      expect(fake.entries.last.last.keys).not_to include("price", "bid", "ask", "quantity")
    end

    it 'returns nil when Redis is unavailable (never raises into the caller)' do
      allow(described_class).to receive(:redis).and_return(UnavailableRedis.new)

      expect(described_class.enqueue(tick)).to be_nil
    end
  end

  describe '.read_last' do
    it 'returns ticks newest-first with a cursor that pages the rest' do
      fake = FakeStreamRedis.new
      allow(described_class).to receive(:redis).and_return(fake)
      3.times { |i| described_class.enqueue(tick(price: 60_000.0 + i)) } # 60000, 60001, 60002

      first_page, cursor = described_class.read_last(count: 2)

      expect(first_page.map(&:price)).to eq([ 60_002.0, 60_001.0 ])
      expect(cursor).to eq(fake.entries.second.first) # id of the page's last item

      second_page, next_cursor = described_class.read_last(count: 2, before_id: cursor)

      expect(second_page.map(&:price)).to eq([ 60_000.0 ])
      expect(next_cursor).to be_nil
    end

    it 'filters by symbol and still fills the page (wider window)' do
      fake = FakeStreamRedis.new
      allow(described_class).to receive(:redis).and_return(fake)
      10.times { described_class.enqueue(tick(symbol: "BTCUSDT")) }
      2.times { |i| described_class.enqueue(tick(symbol: "ETHUSDT", price: 3_000.0 + i)) }

      events, cursor = described_class.read_last(count: 2, symbol: "ethusdt")

      expect(events.map(&:symbol)).to all(eq("ETHUSDT"))
      expect(events.map(&:price)).to eq([ 3_001.0, 3_000.0 ])
      expect(cursor).to be_nil
    end

    it 'returns an empty page when Redis is unavailable' do
      allow(described_class).to receive(:redis).and_return(UnavailableRedis.new)

      events, cursor = described_class.read_last(count: 5)

      expect(events).to eq([])
      expect(cursor).to be_nil
    end
  end
end
