require 'rails_helper'

# Architecture alignment (target architecture §3): QuoteStore specs.
# Venue-aware shared quote store backed by Redis. Holds the freshest
# normalized quote for every (venue, instrument) pair.
RSpec.describe MarketData::QuoteStore, type: :service do
  let(:sample_quote) do
    {
      venue: 'binance_usdm',
      instrument_id: 'BTCUSDT',
      bid: 65_000.0,
      ask: 65_001.0,
      ltp: 65_000.5,
      mark_price: 65_000.5,
      exchange_timestamp: Time.current,
      received_at: Time.current
    }
  end

  describe '.set / .get' do
    it 'round-trips a quote through Redis by (venue, instrument)' do
      described_class.set(sample_quote)
      result = described_class.get('binance_usdm', 'BTCUSDT')
      expect(result[:venue]).to eq('binance_usdm')
      expect(result[:instrument_id]).to eq('BTCUSDT')
      expect(result[:bid]).to eq(65_000.0)
      expect(result[:ask]).to eq(65_001.0)
    end

    it 'isolates quotes by venue for the same symbol' do
      described_class.set(sample_quote)
      described_class.set(sample_quote.merge(venue: 'coindcx_futures', bid: 64_000.0, ask: 64_001.0))

      binance = described_class.get('binance_usdm', 'BTCUSDT')
      coindcx = described_class.get('coindcx_futures', 'BTCUSDT')

      expect(binance[:bid]).to eq(65_000.0)
      expect(coindcx[:bid]).to eq(64_000.0)
    end
  end

  describe '.stale?' do
    it 'returns false for a fresh quote' do
      quote = sample_quote.merge(received_at: Time.current)
      expect(described_class.stale?(quote)).to be false
    end

    it 'returns true for a quote older than the threshold' do
      quote = sample_quote.merge(received_at: 2.minutes.ago)
      expect(described_class.stale?(quote)).to be true
    end

    it 'returns true for nil' do
      expect(described_class.stale?(nil)).to be true
    end
  end
end
