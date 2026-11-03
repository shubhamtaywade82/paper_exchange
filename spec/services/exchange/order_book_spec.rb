require 'rails_helper'

RSpec.describe Exchange::OrderBook, type: :service do
  let(:book) { described_class.new(Mutex.new, {}) }

  it 'applies snapshots and returns book state' do
    book.apply_snapshot('RELIANCE', bid: 100.0, ask: 100.5, ltp: 100.25, depth: 5)
    snap = book.snapshot('RELIANCE')
    expect(snap[:bid]).to eq(100.0)
    expect(snap[:ask]).to eq(100.5)
    expect(snap[:ltp]).to eq(100.25)
    expect(snap[:source]).to eq(:feed)
  end

  describe 'depth' do
    it 'is nil when the feed does not supply it, never a fabricated level' do
      book.apply_snapshot('RELIANCE', bid: 100.0, ask: 100.5, ltp: 100.25)

      expect(book.depth('RELIANCE')).to be_nil
    end

    it 'is nil for a mark-derived book as well' do
      allow(MarketData::MarkPriceStore).to receive(:get).with('RELIANCE').and_return(100.0)

      expect(book.snapshot('RELIANCE')).to include(source: :mark_derived, depth: nil)
    end
  end

  describe 'with no feed snapshot' do
    it 'labels a mark-derived book as a model, not as observed quotes' do
      allow(MarketData::MarkPriceStore).to receive(:get).with('RELIANCE').and_return(100.0)

      snap = book.snapshot('RELIANCE')

      expect(snap[:source]).to eq(:mark_derived)
      expect(snap[:bid]).to be_within(1e-9).of(99.98)
      expect(snap[:ask]).to be_within(1e-9).of(100.02)
    end

    it 'uses a fixed test book when no mark exists in the test environment' do
      allow(MarketData::MarkPriceStore).to receive(:get).with('RELIANCE').and_return(nil)

      expect(book.snapshot('RELIANCE')).to include(source: :test_fixture, bid: 100.0, ask: 101.0)
    end

    it 'refuses to price a symbol outside the test environment when neither a feed nor a mark exists' do
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(MarketData::MarkPriceStore).to receive(:get).with('RELIANCE').and_return(nil)

      expect { book.snapshot('RELIANCE') }.to raise_error(RuntimeError, /No market data for RELIANCE/)
    end
  end
end
