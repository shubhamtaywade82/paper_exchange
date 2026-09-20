require 'rails_helper'

RSpec.describe PaperExchange::PaperPosition, type: :model do
  subject { build(:paper_position) }
  it { is_expected.to validate_presence_of(:symbol) }
  it { is_expected.to validate_presence_of(:side) }
  it { is_expected.to validate_numericality_of(:quantity) }
  it { is_expected.to validate_numericality_of(:avg_price).is_greater_than_or_equal_to(0).allow_nil }
  it { is_expected.to validate_numericality_of(:current_price).is_greater_than_or_equal_to(0).allow_nil }
  it { is_expected.to validate_numericality_of(:leverage).only_integer.is_greater_than_or_equal_to(1) }
  it { is_expected.to validate_numericality_of(:initial_margin).is_greater_than_or_equal_to(0) }
  it { is_expected.to allow_value('cross').for(:margin_type) }
  it { is_expected.to allow_value('isolated').for(:margin_type) }
  it { is_expected.not_to allow_value('crossed').for(:margin_type) }

  it 'accepts a fractional (crypto) quantity' do
    position = build(:paper_position, symbol: 'BTCUSDT', quantity: 0.005)
    expect(position).to be_valid
  end

  describe '#liquidated?' do
    it 'is false for an unleveraged position regardless of price' do
      position = build(:paper_position, leverage: 1, liquidation_price: nil)
      expect(position.liquidated?(1.0)).to be false
    end

    it 'is true once the mark price breaches a long liquidation price' do
      position = build(:paper_position, side: :long, leverage: 10, liquidation_price: 54_000.0)
      expect(position.liquidated?(53_999.0)).to be true
      expect(position.liquidated?(54_001.0)).to be false
    end

    it 'is true once the mark price breaches a short liquidation price' do
      position = build(:paper_position, side: :short, leverage: 10, liquidation_price: 66_000.0)
      expect(position.liquidated?(66_001.0)).to be true
      expect(position.liquidated?(65_999.0)).to be false
    end
  end
end
