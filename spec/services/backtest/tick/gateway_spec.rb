require 'rails_helper'

# A market order walks the L2 book and books each consumed level as one slice,
# through the live fill path, so every slice has its own execution_key and charges.
RSpec.describe Backtest::Tick::Gateway, type: :service do
  let(:time) { Time.utc(2026, 11, 3, 4, 0) }
  let(:book) do
    Backtest::Tick::HistoricalOrderBook.new(symbol: 'RELIANCE', timestamp: time,
      bids: [ [ '99.90', '4' ] ], asks: [ [ '100.00', '2' ], [ '100.10', '3' ], [ '100.20', '5' ] ])
  end
  let(:order) do
    create(:paper_order, symbol: 'RELIANCE', side: 'buy', order_kind: 'market', quantity: 4, instrument_type: 'EQUITY')
  end
  let(:gateway) { described_class.new(fill_engine: Exchange::FillEngine.new(slippage: nil)) }

  before { create(:account, account_id: order.account_id) if Account.find_by(account_id: order.account_id).nil? }

  it 'books one slice per consumed level, priced at the level, not at a model price' do
    result = gateway.execute_market!(order: order, book: book, quantity: 4, instrument_type: 'EQUITY')

    expect(result.trades.map(&:price)).to eq([ BigDecimal('100.00'), BigDecimal('100.10') ])
    expect(result.trades.map(&:quantity)).to eq([ BigDecimal('2'), BigDecimal('2') ])
    expect(result.filled_quantity).to eq(4)
    expect(result.remaining_quantity).to eq(0)
  end

  it 'gives each slice its own execution key and a book_l2 liquidity source' do
    trades = gateway.execute_market!(order: order, book: book, quantity: 4, instrument_type: 'EQUITY').trades

    expect(trades.map(&:execution_key)).to eq([ "#{order.id}:1", "#{order.id}:2" ])
    expect(trades.map(&:liquidity_source)).to all(eq('book_l2'))
  end

  it 'reflects the depth it consumed in the next order' do
    gateway.execute_market!(order: order, book: book, quantity: 4, instrument_type: 'EQUITY')

    # 100.10 had 3 units and the order took 2, so 1 is left.
    expect(book.depth(:asks).first).to eq([ BigDecimal('100.10'), BigDecimal('1') ])
  end

  it 'reports an unfilled remainder when depth runs out, and books only what it filled' do
    result = gateway.execute_market!(order: order, book: book, quantity: 30, instrument_type: 'EQUITY')

    expect(result.filled_quantity).to eq(10)
    expect(result.remaining_quantity).to eq(20)
    expect(result.trades.sum(&:quantity)).to eq(10)
  end
end
