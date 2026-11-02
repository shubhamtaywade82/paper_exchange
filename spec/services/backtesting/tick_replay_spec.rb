require "rails_helper"

RSpec.describe Backtesting::TickReplay do
  it "replays chronologically with sequence as a stable tie-breaker" do
    events = [
      { timestamp: "2025-01-01T00:00:01Z", sequence: 2, id: :b },
      { timestamp: "2025-01-01T00:00:00Z", sequence: 1, id: :a },
      { timestamp: "2025-01-01T00:00:01Z", sequence: 1, id: :c }
    ]
    expect(described_class.new(events).map { |event, _time, _sequence| event[:id] }).to eq(%i[a c b])
  end

  it "rejects events without valid timestamps" do
    expect { described_class.new([{ sequence: 1 }]) }.to raise_error(ArgumentError)
  end
end
