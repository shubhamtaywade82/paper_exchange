require 'rails_helper'

RSpec.describe Clock, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  it 'reads wall-clock time in UTC outside a simulation' do
    travel_to(Time.utc(2026, 11, 3, 4, 0)) do
      expect(described_class.now).to eq(Time.utc(2026, 11, 3, 4, 0))
      expect(described_class.now.utc_offset).to eq(0)
    end
  end

  it 'reads simulated time inside a backtest session, and only there' do
    session = Backtest::Session.new(risk_gate: false)
    session.at = Time.utc(2025, 1, 2, 9, 15)

    Backtest::Session.with(session) do
      expect(described_class.now).to eq(Time.utc(2025, 1, 2, 9, 15))
    end
    expect(Backtest::Session.current).to be_nil
  end

  describe '.exchange_date' do
    it 'uses the exchange calendar date, so 19:00 UTC on the 2nd is already the 3rd in India' do
      expect(described_class.exchange_date(zone: 'Asia/Kolkata', at: Time.utc(2026, 11, 2, 19, 0)))
        .to eq(Date.new(2026, 11, 3))
    end

    it 'is still the 2nd in UTC for that same instant' do
      expect(described_class.exchange_date(zone: 'UTC', at: Time.utc(2026, 11, 2, 19, 0)))
        .to eq(Date.new(2026, 11, 2))
    end
  end
end
