require 'rails_helper'

RSpec.describe Risk::MarginValidator, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:validator) { described_class.new }
  let(:signal) { instance_double('Strategy::Signal', to_h: signal_h) }

  before { create(:account, account_id: account_id) }

  context 'with a fractional crypto quantity' do
    let(:signal_h) { { symbol: 'BTCUSDT', quantity: 0.01, price: 65_000.0, instrument_type: 'CRYPTO_PERPETUAL' } }

    it 'passes when the notional is under MAX_POSITION_VALUE' do
      expect(validator.evaluate(account_id, signal)).to eq(:passed)
    end

    it 'rejects when the fractional notional exceeds MAX_POSITION_VALUE (B2 regression guard)' do
      stub_const('Risk::MarginValidator::MAX_POSITION_VALUE', 100.0)
      expect(validator.evaluate(account_id, signal)).to eq(:MARGIN_REJECTED)
    end
  end

  context 'with an integer equity quantity' do
    let(:signal_h) { { symbol: 'RELIANCE', quantity: 10, price: 2_500.0, instrument_type: 'EQUITY' } }

    it 'passes when under the limit' do
      expect(validator.evaluate(account_id, signal)).to eq(:passed)
    end
  end
end
