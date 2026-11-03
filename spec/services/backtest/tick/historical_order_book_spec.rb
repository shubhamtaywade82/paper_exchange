require 'rails_helper'

RSpec.describe Backtest::Tick::HistoricalOrderBook, type: :service do
  let(:time) { Time.utc(2026, 11, 3, 4, 0) }
  let(:asks) { [ [ '100.00', '2' ], [ '100.10', '3' ], [ '100.20', '5' ] ] }
  let(:bids) { [ [ '99.90', '4' ], [ '99.80', '6' ] ] }
  let(:book) { described_class.new(symbol: 'SOLUSDT', bids: bids, asks: asks, timestamp: time) }

  def book_with(bids: self.bids, asks: self.asks)
    described_class.new(symbol: 'SOLUSDT', bids: bids, asks: asks, timestamp: time)
  end

  describe 'construction and validation' do
    it 'refuses a non-positive price' do
      expect { book_with(asks: [ [ '0', '1' ] ]) }.to raise_error(ArgumentError, /asks price must be finite and positive/)
    end

    it 'refuses a zero or negative quantity in a snapshot' do
      expect { book_with(asks: [ [ '100', '0' ] ]) }.to raise_error(ArgumentError, /asks quantity must be finite and positive/)
      expect { book_with(asks: [ [ '100', '-1' ] ]) }.to raise_error(ArgumentError, /asks quantity/)
    end

    it 'refuses duplicate price levels' do
      expect { book_with(asks: [ [ '100', '1' ], [ '100', '2' ] ]) }
        .to raise_error(described_class::InvalidBook, /duplicate price levels/)
    end

    it 'refuses a crossed book' do
      expect { book_with(bids: [ [ '100.10', '1' ] ], asks: [ [ '100.00', '1' ] ]) }
        .to raise_error(described_class::CrossedBook)
    end

    it 'refuses a non-numeric price with a clear reason' do
      expect { book_with(asks: [ [ 'abc', '1' ] ]) }.to raise_error(ArgumentError, /must be a finite decimal/)
    end

    it 'refuses an invalid symbol' do
      expect { described_class.new(symbol: 'sol usdt', bids: bids, asks: asks, timestamp: time) }
        .to raise_error(described_class::InvalidBook, /invalid symbol/)
    end

    it 'keeps every price and quantity as a BigDecimal' do
      expect(book.best_ask).to be_a(BigDecimal)
      expect(book.execute(side: 'buy', quantity: 1).fills.first[:quantity]).to be_a(BigDecimal)
    end
  end

  describe 'market execution' do
    it 'walks asks for a buy, with VWAP from the consumed slices' do
      result = book.execute(side: 'buy', quantity: 4)

      expect(result.fills.map { |f| [ f[:price], f[:quantity] ] })
        .to eq([ [ BigDecimal('100.00'), BigDecimal('2') ], [ BigDecimal('100.10'), BigDecimal('2') ] ])
      expect(result.average_price).to eq(BigDecimal('100.05'))
      expect(result.complete?).to be(true)
    end

    it 'walks bids for a sell, from the highest bid down' do
      result = book.execute(side: 'sell', quantity: 5)

      expect(result.fills.map { |f| f[:price] }).to eq([ BigDecimal('99.90'), BigDecimal('99.80') ])
      expect(result.filled_quantity).to eq(5)
    end

    it 'reports the best price as the top of book' do
      expect(book.execute(side: 'buy', quantity: 1).top_of_book).to eq(BigDecimal('100.00'))
    end

    it 'returns a partial fill when depth is insufficient, and reports the remainder' do
      result = book.execute(side: 'buy', quantity: 20)

      expect(result.filled_quantity).to eq(10)
      expect(result.remaining_quantity).to eq(10)
      expect(result.complete?).to be(false)
      # (2 x 100.00 + 3 x 100.10 + 5 x 100.20) / 10 = 1001.30 / 10
      expect(result.average_price).to eq(BigDecimal('100.13'))
    end

    it 'fills nothing and reports the whole quantity when a side is empty' do
      empty = book_with(asks: [ [ '100.00', '1' ] ], bids: [ [ '99.90', '1' ] ])
      empty.execute(side: 'buy', quantity: 1) # consumes the only ask
      result = empty.execute(side: 'buy', quantity: 1)

      expect(result.filled_quantity).to eq(0)
      expect(result.remaining_quantity).to eq(1)
      expect(result.average_price).to be_nil
    end

    it 'refuses a non-positive order quantity' do
      expect { book.execute(side: 'buy', quantity: 0) }.to raise_error(ArgumentError, /quantity must be finite and positive/)
    end

    it 'refuses an unknown side' do
      expect { book.execute(side: 'hold', quantity: 1) }.to raise_error(ArgumentError, /side must be buy or sell/)
    end

    it 'refuses a level beyond the slippage bound, and fills only what is inside it' do
      result = book.execute(side: 'buy', quantity: 10, max_slippage_bps: 5)

      expect(result.fills.map { |f| f[:price] }).to eq([ BigDecimal('100.00') ])
      expect(result.remaining_quantity).to eq(8)
    end
  end

  describe 'depth consumption' do
    it 'shows a second order the liquidity the first one left' do
      book.execute(side: 'buy', quantity: 4)
      second = book.execute(side: 'buy', quantity: 2)

      expect(second.fills.map { |f| [ f[:price], f[:quantity] ] }).to eq([ [ BigDecimal('100.10'), BigDecimal('1') ], [ BigDecimal('100.20'), BigDecimal('1') ] ])
      # 100.10 is used up by the second order, so 100.20 now leads with 5 - 1 = 4.
      expect(book.depth(:asks).first).to eq([ BigDecimal('100.20'), BigDecimal('4') ])
    end

    it 'removes a level that is fully consumed' do
      book.execute(side: 'buy', quantity: 2)

      expect(book.best_ask).to eq(BigDecimal('100.10'))
    end
  end

  describe 'depth deltas' do
    it 'sets the quantity at a level, adding it when absent' do
      book.apply_delta(side: 'asks', price: '100.05', quantity: '7', timestamp: time + 1)

      expect(book.best_ask).to eq(BigDecimal('100.00'))
      expect(book.depth(:asks)).to include([ BigDecimal('100.05'), BigDecimal('7') ])
    end

    it 'removes a level when its quantity is set to zero' do
      book.apply_delta(side: 'asks', price: '100.00', quantity: '0', timestamp: time + 1)

      expect(book.best_ask).to eq(BigDecimal('100.10'))
    end

    it 'refuses a delta that would cross the book, and leaves the book unchanged' do
      expect {
        book.apply_delta(side: 'bids', price: '100.50', quantity: '1', timestamp: time + 1)
      }.to raise_error(described_class::CrossedBook)

      expect(book.best_bid).to eq(BigDecimal('99.90'))
    end

    it 'refuses a negative delta quantity' do
      expect { book.apply_delta(side: 'asks', price: '100', quantity: '-1', timestamp: time) }
        .to raise_error(ArgumentError, /quantity must be finite and non-negative/)
    end

    it 'refuses an unknown side' do
      expect { book.apply_delta(side: 'mid', price: '100', quantity: '1', timestamp: time) }
        .to raise_error(described_class::InvalidBook, /side must be bids or asks/)
    end
  end
end
