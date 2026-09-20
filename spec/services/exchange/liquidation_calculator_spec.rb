require 'rails_helper'

RSpec.describe Exchange::LiquidationCalculator, type: :service do
  describe '.liquidation_price' do
    it 'returns nil for unleveraged (leverage <= 1) positions' do
      expect(described_class.liquidation_price(entry_price: 100.0, leverage: 1, side: 'long')).to be_nil
    end

    it 'returns nil when there is no entry price yet' do
      expect(described_class.liquidation_price(entry_price: nil, leverage: 10, side: 'long')).to be_nil
    end

    it 'computes a liquidation price below entry for a long position' do
      price = described_class.liquidation_price(entry_price: 100.0, leverage: 10, side: 'long', maintenance_margin_rate: 0.004)
      expect(price).to be_within(0.001).of(100.0 * (1 - 0.1 + 0.004))
      expect(price).to be < 100.0
    end

    it 'computes a liquidation price above entry for a short position' do
      price = described_class.liquidation_price(entry_price: 100.0, leverage: 10, side: 'short', maintenance_margin_rate: 0.004)
      expect(price).to be_within(0.001).of(100.0 * (1 + 0.1 - 0.004))
      expect(price).to be > 100.0
    end

    it 'raises for an unknown side' do
      expect {
        described_class.liquidation_price(entry_price: 100.0, leverage: 10, side: 'sideways')
      }.to raise_error(ArgumentError)
    end
  end

  describe '.initial_margin' do
    it 'divides notional by leverage' do
      expect(described_class.initial_margin(notional: 1_000.0, leverage: 10)).to eq(100.0)
    end

    it 'treats leverage below 1 as 1x' do
      expect(described_class.initial_margin(notional: 1_000.0, leverage: 0)).to eq(1_000.0)
    end
  end
end
