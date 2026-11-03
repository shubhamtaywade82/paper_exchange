require 'rails_helper'

RSpec.describe Exchange::SlippageEngine, type: :service do
  let(:engine) { described_class.new }

  describe '#apply' do
    it 'moves an equity buy up by the equity fraction of price' do
      expect(engine.apply(price: 100.0, side: 'buy', instrument_type: 'EQUITY')).to be_within(1e-9).of(100.02)
    end

    it 'moves a sell down by the same fraction' do
      expect(engine.apply(price: 100.0, side: 'sell', instrument_type: 'EQUITY')).to be_within(1e-9).of(99.98)
    end

    it 'applies higher impact for options' do
      equity = engine.apply(price: 100.0, side: 'buy', instrument_type: 'EQUITY')
      option = engine.apply(price: 100.0, side: 'buy', instrument_type: 'OPTIDX')
      expect(option).to be > equity
    end

    it 'applies the option fraction to commodity and currency options too' do
      expect(engine.apply(price: 100.0, side: 'buy', instrument_type: 'OPTCUR'))
        .to be_within(1e-9).of(100.05)
    end

    it 'has the same relative impact at a 0.50 price and a 100,000 price' do
      low = engine.apply(price: 0.5, side: 'buy') / 0.5
      high = engine.apply(price: 100_000.0, side: 'buy') / 100_000.0

      expect(low).to be_within(1e-12).of(high)
    end

    it 'does not depend on quantity, because size is not visible without depth' do
      expect(engine.method(:apply).parameters.map(&:last)).not_to include(:quantity)
    end

    it 'caps the impact at the maximum fraction' do
      capped = described_class.new(equity_impact_fraction: 0.5, max_fraction: 0.01)

      expect(capped.apply(price: 100.0, side: 'buy')).to be_within(1e-9).of(101.0)
    end

    it 'leaves a zero price at zero, which is how an out-of-the-money option settles' do
      expect(engine.apply(price: 0, side: 'sell', instrument_type: 'OPTIDX')).to eq(0)
    end

    it 'refuses a negative price' do
      expect { engine.apply(price: -1, side: 'buy') }.to raise_error(ArgumentError, /must not be negative/)
    end
  end
end
