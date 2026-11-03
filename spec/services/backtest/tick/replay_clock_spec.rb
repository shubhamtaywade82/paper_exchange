require 'rails_helper'

RSpec.describe Backtest::Tick::ReplayClock, type: :service do
  it 'starts at the given instant, in UTC' do
    expect(described_class.new(start_at: '2026-11-03T04:00:00+05:30').now).to eq(Time.utc(2026, 11, 2, 22, 30))
  end

  it 'advances with event time' do
    clock = described_class.new(start_at: Time.utc(2026, 11, 3, 4))
    clock.advance!(Time.utc(2026, 11, 3, 4, 0, 1))

    expect(clock.now).to eq(Time.utc(2026, 11, 3, 4, 0, 1))
  end

  it 'refuses to move backwards' do
    clock = described_class.new(start_at: Time.utc(2026, 11, 3, 4))

    expect { clock.advance!(Time.utc(2026, 11, 3, 3)) }.to raise_error(ArgumentError, /cannot move backwards/)
  end
end
