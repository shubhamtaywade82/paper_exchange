require 'rails_helper'

RSpec.describe PaperExchange::PaperOrder, type: :model do
  subject(:order) { build(:paper_order, attrs) }
  let(:attrs) { { order_kind: :market, instrument_type: 'EQUITY', option_type: nil } }

  it { is_expected.to validate_presence_of(:symbol) }
  it { is_expected.to validate_presence_of(:side) }
  it { is_expected.to validate_presence_of(:order_kind) }
  it { is_expected.to validate_presence_of(:quantity) }
  it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than(0) }

  context 'when instrument_type is missing' do
    let(:attrs) { { order_kind: :market, instrument_type: nil } }
    it { is_expected.to validate_presence_of(:instrument_type) }
  end

  context 'when instrument_type is invalid' do
    let(:attrs) { { order_kind: :market, instrument_type: 'INVALID_TYPE' } }
    it 'is not valid' do
      expect(order.valid?).to be_falsey
      expect(order.errors[:instrument_type]).to be_present
    end
  end

  context 'index derivative-only rule' do
    let(:attrs) { { symbol: 'NIFTY', instrument_type: 'EQUITY', order_kind: :market } }
    it 'rejects cash index orders' do
      expect(order.valid?).to be_falsey
      expect(order.errors[:instrument_type]).to include(
        a_string_matching(/Indices must be traded via F&O derivatives only/)
      )
    end
  end

  context 'with valid derivative index order' do
    let(:attrs) { { symbol: 'NIFTY', instrument_type: 'FUTIDX', option_type: nil } }
    it { is_expected.to be_valid }
  end

  context 'option_validations' do
    let(:attrs) { { option_type: 'CE', strike_price: 26000, expiry_date: Date.today + 7 } }
    it { is_expected.to be_valid }
  end

  context 'when option_type is set but expiry_date is missing' do
    let(:attrs) { { option_type: 'CE', expiry_date: nil } }
    it { is_expected.not_to allow_value(nil).for(:expiry_date) }
  end

  describe '#remaining_quantity' do
    let(:attrs) { { quantity: 100, filled_quantity: 30 } }
    it 'returns unfilled quantity' do
      expect(order.remaining_quantity).to eq(70)
    end
  end

  describe '#cancel!' do
    let(:attrs) { { status: :open } }
    it 'cancels the order' do
      order.cancel!
      expect(order.reload.status).to eq('cancelled')
    end
  end

  describe '#rejected!' do
    it 'marks order rejected' do
      order.save!
      order.rejected!('test reason')
      expect(order.reload.status).to eq('rejected')
      expect(order.rejection_reason).to eq('test reason')
    end
  end
end
