require "rails_helper"

RSpec.describe Backtesting::ReplayClock do
  it "advances using supplied historical timestamps" do
    clock = described_class.new(start_at: "2025-01-01T00:00:00Z")
    clock.advance!("2025-01-01T00:01:00Z")
    expect(clock.now).to eq(Time.iso8601("2025-01-01T00:01:00Z"))
  end

  it "rejects backwards time" do
    clock = described_class.new(start_at: "2025-01-01T00:01:00Z")
    expect { clock.advance!("2025-01-01T00:00:00Z") }.to raise_error(ArgumentError, /backwards/)
  end
end
