require 'rails_helper'

RSpec.describe Risk::MarginValidator, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:validator) { described_class.new }
  let(:signal) { instance_double('Strategy::Signal', to_h: signal_h) }

  before { create(:account, account_id: account_id, margin: 10_000.0, available_balance: 10_000.0) }

  context 'with a fractional crypto quantity' do
    let(:signal_h) { { symbol: 'BTCUSDT', quantity: 0.01, price: 65_000.0, instrument_type: 'CRYPTO_PERPETUAL', leverage: 10 } }

    it 'passes when the notional is under MAX_POSITION_VALUE and margin is sufficient' do
      expect(validator.evaluate(account_id, signal)).to eq(:passed)
    end

    it 'rejects when the fractional notional exceeds MAX_POSITION_VALUE (B2 regression guard)' do
      stub_const('Risk::MarginValidator::MAX_POSITION_VALUE', 100.0)
      expect(validator.evaluate(account_id, signal)).to eq(:MARGIN_REJECTED)
    end

    it 'rejects when available_balance is less than the required margin (#6 regression guard)' do
      # 0.01 * 65000 = 650 notional, 10x leverage = 65 required margin.
      # Drain the account to 10 — should reject.
      Account.find_by(account_id: account_id).update_columns(available_balance: 10.0)
      expect(validator.evaluate(account_id, signal)).to eq(:MARGIN_REJECTED)
    end
  end

  context 'with an integer equity quantity' do
    let(:signal_h) { { symbol: 'RELIANCE', quantity: 10, price: 2_500.0, instrument_type: 'EQUITY', leverage: 1 } }

    it 'passes when under the limit' do
      expect(validator.evaluate(account_id, signal)).to eq(:passed)
    end
  end
end
