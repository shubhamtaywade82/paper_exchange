require "rails_helper"

RSpec.describe Backtesting::HistoricalOrderBook do
  subject(:book) do
    described_class.new(symbol: "SOLUSDT",
      bids: [[100.0, 2.0], [99.0, 3.0]],
      asks: [[101.0, 1.0], [102.0, 2.0]],
      timestamp: "2025-01-01T00:00:00Z")
  end

  it "executes buys across ask levels at volume weighted prices" do
    result = book.execute(side: :buy, quantity: 2.0)
    expect(result.filled_quantity).to eq(2.0)
    expect(result.average_price).to eq(101.5)
    expect(result.fills).to eq([{ price: 101.0, quantity: 1.0 }, { price: 102.0, quantity: 1.0 }])
  end

  it "returns partial fills when visible depth is insufficient" do
    result = book.execute(side: :sell, quantity: 10.0)
    expect(result.filled_quantity).to eq(5.0)
    expect(result.remaining_quantity).to eq(5.0)
    expect(result.complete?).to be(false)
  end

  it "consumes depth so a second order cannot reuse liquidity" do
    book.execute(side: :buy, quantity: 1.0)
    result = book.execute(side: :buy, quantity: 1.0)
    expect(result.average_price).to eq(102.0)
  end

  it "rejects crossed books" do
    expect {
      described_class.new(symbol: "SOLUSDT", bids: [[102, 1]], asks: [[101, 1]], timestamp: Time.utc(2025))
    }.to raise_error(ArgumentError, /crossed/)
  end

  it "enforces a maximum adverse execution distance" do
    result = book.execute(side: :buy, quantity: 2.0, max_slippage_bps: 50)
    expect(result.filled_quantity).to eq(1.0)
    expect(result.remaining_quantity).to eq(1.0)
  end
end
