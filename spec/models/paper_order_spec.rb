require 'rails_helper'

RSpec.describe PaperExchange::PaperOrder, type: :model do
  subject(:order) { build(:paper_order, attrs) }
  let(:attrs) { { order_kind: :market, instrument_type: 'EQUITY', option_type: nil } }

  it { is_expected.to validate_presence_of(:symbol) }
  it { is_expected.to validate_presence_of(:side) }
  it { is_expected.to validate_presence_of(:order_kind) }
  it { is_expected.to validate_presence_of(:quantity) }
  it { is_expected.to validate_numericality_of(:quantity).is_greater_than(0) }

  context 'with a fractional (crypto) quantity' do
    let(:attrs) { { order_kind: :market, instrument_type: Exchange::CryptoInstrumentCatalog::PERPETUAL, symbol: 'BTCUSDT', quantity: 0.005 } }
    it { is_expected.to be_valid }
  end

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
    let(:attrs) { { status: :open, instrument_type: 'EQUITY', symbol: 'RELIANCE' } }
    it 'cancels the order' do
      order.save!
      order.cancel!
      expect(order.reload.status).to eq('cancelled')
    end
  end

  describe '#rejected!' do
    let(:attrs) { { status: :open, instrument_type: 'EQUITY', symbol: 'RELIANCE' } }
    it 'marks order rejected' do
      order.save!
      order.rejected!('test reason')
      expect(order.reload.status).to eq('rejected')
      expect(order.rejection_reason).to eq('test reason')
    end
  end
  # Audit S1/N1 (T3.1): the full legal-transition table. Terminal states
  # can never transition again; rejected! stays unguarded by design (it is
  # the terminal safety net in submit_order's rescue path).
  describe 'state transition guards (audit S1)' do
    let(:order) { create(:paper_order, status: :pending) }

    def transition_table
      {
        cancel: %i[pending open partially_filled],
        open: %i[pending partially_filled],
        fill: %i[open partially_filled],
        partially_fill: %i[open partially_filled],
        expire: %i[pending open partially_filled]
      }
    end

    ALL_STATUSES = %i[pending open partially_filled filled cancelled rejected expired].freeze

    it 'allows exactly the legal transitions and rejects everything else with StateError' do
      transition_table.each do |action, legal_from|
        ALL_STATUSES.each do |from|
          order.update_columns(status: PaperExchange::PaperOrder.statuses[from])

          apply = lambda do
            case action
            when :cancel then order.cancel!
            when :open then order.open!
            when :fill then order.filled!
            when :partially_fill then order.partially_filled!(1)
            when :expire then order.expired!
            end
          end

          if legal_from.include?(from)
            expect { apply.call }.not_to raise_error, "#{action} from #{from} should be legal"
          else
            expect { apply.call }.to raise_error(PaperExchange::PaperOrder::StateError, /cannot #{action} a #{from}/),
              "#{action} from #{from} should be rejected"
          end
        end
      end
    end

    it 'never raises from rejected! regardless of current status' do
      ALL_STATUSES.each do |from|
        order.update_columns(status: PaperExchange::PaperOrder.statuses[from])
        expect { order.rejected!('reason') }.not_to raise_error
      end
    end
  end
end
