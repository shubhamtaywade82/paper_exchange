require 'rails_helper'

# Audit M4 (T2.1) regression guards: the position upsert must be safe under
# concurrency, and the NULL-dimension unique index must actually fire.
#
# Transactional fixtures are disabled for this spec: each thread needs its
# own real database transaction (they cannot share the example's
# transaction), so the data is created and cleaned up explicitly.
RSpec.describe Exchange::PositionManager, 'concurrency (audit M4)' do
  self.use_transactional_fixtures = false

  let(:account_id) { 'ACC-CONCURRENCY' }

  before { create(:account, account_id: account_id, margin: 100_000.0) }

  after do
    ::PaperExchange::PaperTrade.where(account_id: account_id).delete_all
    ::PaperExchange::PaperPosition.where(account_id: account_id).delete_all
    ::PaperExchange::PaperOrder.where(account_id: account_id).delete_all
    LedgerEntry.where(account_id: account_id).delete_all
    Account.where(account_id: account_id).delete_all
  end

  def apply_fill(qty, side: 'buy')
    # with_connection returns the thread's connection to the pool when the
    # block ends, so parallel examples do not leak leases.
    ActiveRecord::Base.connection_pool.with_connection do
      Exchange::PositionManager.apply!(
        account_id: account_id,
        symbol: 'BTCUSDT',
        side: side,
        quantity: qty,
        avg_price: 60_000.0,
        leverage: 10,
        instrument_type: 'CRYPTO_PERPETUAL'
      )
    end
  end

  it 'two concurrent first fills from flat produce exactly one position row with the summed quantity' do
    threads = [ 0.1, 0.1 ].map { |qty| Thread.new { apply_fill(qty) } }
    threads.each(&:join)

    positions = ::PaperExchange::PaperPosition.where(account_id: account_id, symbol: 'BTCUSDT')
    expect(positions.count).to eq(1), "expected exactly one position row, found #{positions.count}"
    expect(positions.first.quantity.to_f).to eq(0.2)
    expect(positions.first.side).to eq('long')
  end

  it 'a concurrent add and a concurrent reduce still land on one row with the net quantity' do
    apply_fill(1.0)

    threads = [
      Thread.new { apply_fill(0.5) },
      Thread.new { apply_fill(0.25, side: 'sell') }
    ]
    threads.each(&:join)

    positions = ::PaperExchange::PaperPosition.where(account_id: account_id, symbol: 'BTCUSDT')
    expect(positions.count).to eq(1)
    expect(positions.first.quantity.to_f).to eq(1.25)
  end

  it 'serializes double adds through the row lock so quantity is never lost' do
    apply_fill(0.1)

    threads = 5.times.map { Thread.new { apply_fill(0.1) } }
    threads.each(&:join)

    position = ::PaperExchange::PaperPosition.find_by!(account_id: account_id, symbol: 'BTCUSDT')
    expect(position.quantity.to_f).to eq(0.6)
  end
end
