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
    # Audit S3/T3.5: unleveraged instruments lock the FULL notional (see
    # PaperOrder#required_margin), so the gate compares against the same
    # figure — not a fraction of it. An oversized equity order now gets a
    # clean pre-mutation 422 here instead of a 402 at MarginLedger after
    # the order row was already saved.
    let(:signal_h) { { symbol: 'RELIANCE', quantity: 2, price: 2_500.0, instrument_type: 'EQUITY', leverage: 1 } }

    it 'passes when the full notional fits within available_balance' do
      expect(validator.evaluate(account_id, signal)).to eq(:passed)
    end

    it 'rejects an order whose full notional exceeds half the balance (50%-of-balance order, audit S3)' do
      Account.find_by(account_id: account_id).update_columns(available_balance: 4_000.0)
      expect(validator.evaluate(account_id, signal)).to eq(:MARGIN_REJECTED)
    end

    it 'rejects an oversized equity order pre-mutation instead of letting it die at the margin lock' do
      oversized = instance_double('Strategy::Signal', to_h: {
        symbol: 'RELIANCE', quantity: 10, price: 2_500.0, instrument_type: 'EQUITY', leverage: 1
      })

      expect(validator.evaluate(account_id, oversized)).to eq(:MARGIN_REJECTED)
    end
  end
end
