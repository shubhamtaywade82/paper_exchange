require 'rails_helper'

RSpec.describe Exchange::OrderBook, type: :service do
  it 'applies snapshots and returns book state' do
    book = Exchange::OrderBook.new(Mutex.new, {})
    book.apply_snapshot('RELIANCE', bid: 100.0, ask: 100.5, ltp: 100.25, depth: 5)
    snap = book.snapshot('RELIANCE')
    expect(snap[:bid]).to eq(100.0)
    expect(snap[:ask]).to eq(100.5)
    expect(snap[:ltp]).to eq(100.25)
  end
end
