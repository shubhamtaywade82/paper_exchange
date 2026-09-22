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
        order_kind: 'market',
        instrument_type: 'FUTIDX'
      }
    end

    context 'with valid attrs' do
      let(:attrs) { base_attrs }
      it 'returns the validated hash' do
        expect(call[:symbol]).to eq('NIFTY')
      end
    end

    context 'with invalid side' do
      let(:attrs) { base_attrs.merge(side: 'invalid') }
      it 'raises OrderValidationError' do
        expect { call }.to raise_error(Exchange::OrderValidationError, /side/)
      end
    end

    context 'with quantity zero' do
      let(:attrs) { base_attrs.merge(quantity: 0) }
      it 'raises' do
        expect { call }.to raise_error(Exchange::OrderValidationError)
      end
    end

    context 'with invalid instrument_type' do
      let(:attrs) { base_attrs.merge(instrument_type: 'UNKNOWN') }
      it 'raises' do
        expect { call }.to raise_error(Exchange::OrderValidationError)
      end
    end

    context 'with index as equity' do
      let(:attrs) { base_attrs.merge(symbol: 'NIFTY', instrument_type: 'EQUITY') }
      it 'raises derivative-only error' do
        expect { call }.to raise_error(Exchange::OrderValidationError, /Indices must be traded via F&O derivatives only/)
      end
    end

    context 'with option fields' do
      let(:attrs) { base_attrs.merge(option_type: 'CE', strike_price: 26_000, expiry_date: Date.today + 7) }
      it 'preserves option fields' do
        expect(call[:option_type]).to eq('CE')
      end
    end

    context 'with a fractional crypto quantity (B2 regression guard)' do
      let(:attrs) { base_attrs.merge(symbol: 'BTCUSDT', quantity: 0.01, instrument_type: 'CRYPTO_PERPETUAL', leverage: 10) }
      it 'accepts the decimal quantity' do
        expect(call[:quantity].to_f).to eq(0.01)
      end
    end

    context 'with ActionController::Parameters input (controller path)' do
      let(:attrs) do
        ActionController::Parameters.new(
          account_id: 'ACC-001', symbol: 'NIFTY', side: 'buy',
          quantity: 50, order_kind: 'market', instrument_type: 'FUTIDX'
        )
      end
      it 'reads through to_unsafe_h so non-permitted keys (account_id, order_kind) survive' do
        expect(call[:account_id]).to eq('ACC-001')
        expect(call[:order_kind]).to eq('market')
      end
    end
  end
end
