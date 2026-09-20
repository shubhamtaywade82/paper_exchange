require 'rails_helper'

RSpec.describe MarketData::MarkPriceStore, type: :service do
  let(:fake_redis) do
    Class.new do
      def initialize
        @store = {}
      end

      def hset(_key, field, value)
        @store[field] = value
      end

      def hget(_key, field)
        @store[field]
      end

      def hgetall(_key)
        @store.dup
      end

      def del(_key)
        @store.clear
      end
    end.new
  end

  before do
    described_class.instance_variable_set(:@local_cache, nil)
    allow(described_class).to receive(:redis).and_return(fake_redis)
  end

  describe '.set / .get' do
    it 'round-trips a price through the in-process cache' do
      described_class.set('btcusdt', 65123.45)
      expect(described_class.get('BTCUSDT')).to eq(65123.45)
    end

    it 'is case-insensitive on the symbol' do
      described_class.set('BTCUSDT', 100.0)
      expect(described_class.get('btcusdt')).to eq(100.0)
    end

    it 'falls back to Redis when the in-process cache is empty' do
      described_class.set('ETHUSDT', 3000.0)
      described_class.instance_variable_set(:@local_cache, nil) # simulate a different process
      expect(described_class.get('ETHUSDT')).to eq(3000.0)
    end

    it 'returns nil for a symbol with no known price' do
      expect(described_class.get('UNKNOWNUSDT')).to be_nil
    end
  end

  describe '.all' do
    it 'returns every stored price' do
      described_class.set('BTCUSDT', 65000.0)
      described_class.set('ETHUSDT', 3000.0)

      expect(described_class.all).to eq('BTCUSDT' => 65000.0, 'ETHUSDT' => 3000.0)
    end
  end

  describe 'Redis outage resilience' do
    it 'degrades .get to nil instead of raising' do
      allow(described_class).to receive(:redis).and_raise(Redis::CannotConnectError.new('down'))
      expect(described_class.get('BTCUSDT')).to be_nil
    end

    it 'degrades .set to a no-op write instead of raising' do
      allow(described_class).to receive(:redis).and_raise(Redis::CannotConnectError.new('down'))
      expect { described_class.set('BTCUSDT', 100.0) }.not_to raise_error
    end
  end
end
