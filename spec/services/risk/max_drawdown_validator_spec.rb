require 'rails_helper'

RSpec.describe Risk::MaxDrawdownValidator, type: :service do
  let(:account_id) { 'ACC-MAX-DD' }
  let(:validator) { described_class.new }
  let(:signal) { instance_double('Strategy::Signal', to_h: { symbol: 'RELIANCE', quantity: 1 }) }

  before { create(:account, account_id: account_id, margin: 10_000.0, current_equity: 10_000.0) }

  it 'defaults to the documented 0.20 when no env var is set' do
    # CI boots without PAPER_EXCHANGE_MAX_DRAWDOWN / PAPER_EXCHANGE_MAX_DD;
    # the documented default (README, .env.example) is 0.20 (audit S9).
    expect(ENV["PAPER_EXCHANGE_MAX_DRAWDOWN"]).to be_nil
    expect(ENV["PAPER_EXCHANGE_MAX_DD"]).to be_nil
    expect(described_class::MAX_DD).to eq(0.20)
  end

  it 'passes while drawdown is within the limit' do
    Account.find_by(account_id: account_id).update_columns(current_equity: 9_000.0) # 10% dd

    expect(validator.evaluate(account_id, signal)).to eq(:passed)
  end

  it 'rejects once drawdown exceeds the limit' do
    stub_const('Risk::MaxDrawdownValidator::MAX_DD', 0.05)
    Account.find_by(account_id: account_id).update_columns(current_equity: 9_000.0) # 10% dd > 5%

    expect(validator.evaluate(account_id, signal)).to eq(:MAX_DD_REJECTED)
  end

  it 'still passes at exactly the 20% boundary and rejects beyond it' do
    Account.find_by(account_id: account_id).update_columns(current_equity: 8_000.0) # exactly 20% dd
    expect(validator.evaluate(account_id, signal)).to eq(:passed)

    Account.find_by(account_id: account_id).update_columns(current_equity: 7_900.0) # 21% dd
    expect(validator.evaluate(account_id, signal)).to eq(:MAX_DD_REJECTED)
  end
end
