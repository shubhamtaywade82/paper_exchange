require 'rails_helper'

RSpec.describe Exchange::OrderValidator, type: :service do
  describe '.call' do
    subject(:call) { described_class.call(attrs) }

    let(:base_attrs) do
      {
        account_id: 'ACC-001',
        symbol: 'NIFTY',
        side: 'buy',
        quantity: 50,
        kind: 'FUTIDX',
        instrument_type: 'FUTIDX'
      }
    end

    context 'with valid attrs' do
      let(:attrs) { base_attrs }
      it 'returns true' do
        expect(call.first).to be_truthy
        expect(call.last[:symbol]).to eq('NIFTY')
      end
    end

    context 'with invalid side' do
      let(:attrs) { base_attrs.merge(side: 'invalid') }
      it 'returns false with errors' do
        expect(call.first).to be_falsey
        expect(call.last).to have_key(:side)
      end
    end

    context 'with quantity zero' do
      let(:attrs) { base_attrs.merge(quantity: 0) }
      it 'returns false with errors' do
        expect(call.first).to be_falsey
      end
    end

    context 'with invalid instrument_type' do
      let(:attrs) { base_attrs.merge(instrument_type: 'UNKNOWN') }
      it 'returns false with errors' do
        expect(call.first).to be_falsey
        expect(call.last).to have_key(:instrument_type)
      end
    end

    context 'with index as equity' do
      let(:attrs) { base_attrs.merge(symbol: 'NIFTY', instrument_type: 'EQUITY') }
      it 'returns false with derivative-only error' do
        expect(call.first).to be_falsey
        expect(call.last[:instrument_type]).to include(
          a_string_matching(/Indices must be traded via F&O derivatives only/)
        )
      end
    end

    context 'with option fields' do
      let(:attrs) { base_attrs.merge(option_type: 'CE', strike_price: 26000, expiry_date: Date.today + 7) }
      it 'returns true and preserves option fields' do
        expect(call.first).to be_truthy
        expect(call.last[:option_type]).to eq('CE')
      end
    end
  end
end
