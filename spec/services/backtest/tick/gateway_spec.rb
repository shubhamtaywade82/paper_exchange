require 'rails_helper'

# A market order walks the L2 book and books each consumed level as one slice,
# through the live fill path, so every slice has its own execution_key and charges.
# The order is then settled from the result.
RSpec.describe Backtest::Tick::Gateway, type: :service do
  let(:time) { Time.utc(2026, 11, 3, 4, 0) }
  let(:asks) { [ [ '100.00', '2' ], [ '100.10', '3' ], [ '100.20', '5' ] ] }
  let(:book) do
    Backtest::Tick::HistoricalOrderBook.new(symbol: 'RELIANCE', timestamp: time,
      bids: [ [ '99.90', '4' ] ], asks: asks)
  end
  let(:quantity) { 4 }
  let(:order) do
    create(:paper_order, symbol: 'RELIANCE', side: 'buy', order_kind: 'market', quantity: quantity,
      instrument_type: 'EQUITY').tap(&:open!)
  end
  let(:gateway) { described_class.new(fill_engine: Exchange::FillEngine.new(slippage: nil)) }

  before { create(:account, account_id: order.account_id) if Account.find_by(account_id: order.account_id).nil? }

  def run!(qty = quantity)
    gateway.execute_market!(order: order, book: book, quantity: qty, instrument_type: 'EQUITY')
  end

  it 'books one slice per consumed level, priced at the level, not at a model price' do
    result = run!

    expect(result.trades.map(&:price)).to eq([ BigDecimal('100.00'), BigDecimal('100.10') ])
    expect(result.trades.map(&:quantity)).to eq([ BigDecimal('2'), BigDecimal('2') ])
    expect(result.filled_quantity).to eq(4)
    expect(result.remaining_quantity).to eq(0)
  end

  it 'gives each slice its own execution key and a book_l2 liquidity source' do
    trades = run!.trades

    expect(trades.map(&:execution_key)).to eq([ "#{order.id}:1", "#{order.id}:2" ])
    expect(trades.map(&:liquidity_source)).to all(eq('book_l2'))
  end

  it 'reflects the depth it consumed in the next order' do
    run!

    # 100.10 had 3 units and the order took 2, so 1 is left.
    expect(book.depth(:asks).first).to eq([ BigDecimal('100.10'), BigDecimal('1') ])
  end

  it 'settles a fully executed order as filled, with its average price' do
    result = run!

    expect(result.status).to eq(:filled)
    expect(order.reload).to have_attributes(status: 'filled', filled_quantity: 4)
    expect(order.avg_fill_price).to eq(BigDecimal('100.05'))
  end

  context 'when depth runs out' do
    let(:quantity) { 30 }

    it 'keeps the executed quantity, cancels the remainder, and says why' do
      result = run!

      expect(result.status).to eq(:cancelled)
      expect(result.filled_quantity).to eq(10)
      expect(result.remaining_quantity).to eq(20)
      expect(result.trades.sum(&:quantity)).to eq(10)
      expect(order.reload).to have_attributes(status: 'cancelled', filled_quantity: 10,
        cancel_reason: 'insufficient_depth')
      expect(order.cancelled_at).to be_present
    end
  end

  context 'when the side has no depth left for a second order' do
    let(:asks) { [ [ '100.00', '4' ] ] }

    it 'cancels it with nothing executed and no average price' do
      run! # the first order takes all four units
      second = create(:paper_order, symbol: 'RELIANCE', side: 'buy', order_kind: 'market', quantity: 1,
        instrument_type: 'EQUITY').tap(&:open!)

      result = gateway.execute_market!(order: second, book: book, quantity: 1, instrument_type: 'EQUITY')

      expect(result.status).to eq(:cancelled)
      expect(result.trades).to be_empty
      expect(second.reload).to have_attributes(status: 'cancelled', filled_quantity: 0, cancel_reason: 'insufficient_depth')
      expect(second.avg_fill_price).to be_nil
    end
  end

  it 'refuses a quantity that is not the order quantity' do
    expect { run!(3) }.to raise_error(ArgumentError, /executed for its full quantity/)
  end

  it 'refuses an order that is not open' do
    pending_order = create(:paper_order, symbol: 'RELIANCE', side: 'buy', order_kind: 'market',
      quantity: quantity, instrument_type: 'EQUITY')

    expect {
      gateway.execute_market!(order: pending_order, book: book, quantity: quantity, instrument_type: 'EQUITY')
    }.to raise_error(ArgumentError, /must be open to execute/)
  end
end
