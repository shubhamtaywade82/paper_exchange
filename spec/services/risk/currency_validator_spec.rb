require 'rails_helper'

# P1-6 regression: currency consistency gate — an INR account cannot trade
# crypto perpetuals (USDT-denominated) and vice versa, so the wallet is
# never a meaningless mixed-currency sum.
RSpec.describe Risk::CurrencyValidator, type: :service do
  let(:account_id_inr) { 'ACC-INR' }
  let(:account_id_usd) { 'ACC-USD' }
  let(:account_id_usdt) { 'ACC-USDT' }

  before do
    create(:account, account_id: account_id_inr, currency: 'INR', margin: 100_000.0)
    create(:account, account_id: account_id_usd, currency: 'USD', margin: 100_000.0)
    create(:account, account_id: account_id_usdt, currency: 'USDT', margin: 100_000.0)
  end

  def signal_for(instrument_type, account_id)
    Strategy::Signal.new(
      account_id: account_id, symbol: 'TEST', side: 'buy', quantity: 1,
      order_kind: 'market', instrument_type: instrument_type, ltp: 100.0,
      context: {}
    )
  end

  it 'allows INR instruments on an INR account' do
    v = described_class.new
    expect(v.evaluate(account_id_inr, signal_for('EQUITY', account_id_inr))).to eq(:passed)
    expect(v.evaluate(account_id_inr, signal_for('FUTIDX', account_id_inr))).to eq(:passed)
    expect(v.evaluate(account_id_inr, signal_for('OPTIDX', account_id_inr))).to eq(:passed)
  end

  it 'allows crypto perpetuals on a USDT account' do
    v = described_class.new
    expect(v.evaluate(account_id_usdt, signal_for('CRYPTO_PERPETUAL', account_id_usdt))).to eq(:passed)
  end

  it 'allows crypto perpetuals on a USD account (USD/USDT compatible)' do
    v = described_class.new
    expect(v.evaluate(account_id_usd, signal_for('CRYPTO_PERPETUAL', account_id_usd))).to eq(:passed)
  end

  it 'rejects crypto perpetuals on an INR account' do
    v = described_class.new
    expect(v.evaluate(account_id_inr, signal_for('CRYPTO_PERPETUAL', account_id_inr))).to eq(:CURRENCY_MISMATCH_REJECTED)
  end

  it 'rejects Indian instruments on a USDT account' do
    v = described_class.new
    expect(v.evaluate(account_id_usdt, signal_for('EQUITY', account_id_usdt))).to eq(:CURRENCY_MISMATCH_REJECTED)
    expect(v.evaluate(account_id_usdt, signal_for('FUTIDX', account_id_usdt))).to eq(:CURRENCY_MISMATCH_REJECTED)
  end
end
