require 'rails_helper'

RSpec.describe Risk::PositionLimitValidator, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:signal) { instance_double('Strategy::Signal', to_h: { symbol: 'NIFTY' }, symbol: 'NIFTY') }
  let(:validator) { described_class.new }

  before { create(:account, account_id: account_id) }

  it 'passes when under limit' do
    # distinct symbols: the strict contract unique index (audit M4) correctly
    # forbids duplicate (account, symbol, instrument) rows with NULL option
    # dimensions — the old specs leaned on the broken composite index.
    5.times { |i| create(:paper_position, account_id: account_id, symbol: "NIFTY#{i}") }
    expect(validator.evaluate(account_id, signal)).to eq(:passed)
  end

  it 'rejects when at or over the limit (B1 regression guard)' do
    stub_const('Risk::PositionLimitValidator::MAX_POSITIONS', 3)
    3.times { |i| create(:paper_position, account_id: account_id, symbol: "NIFTY#{i}") }
    expect(validator.evaluate(account_id, signal)).to eq(:POSITION_LIMIT_REJECTED)
  end

  it 'does not count closed (zero-quantity) position rows against the limit' do
    stub_const('Risk::PositionLimitValidator::MAX_POSITIONS', 3)
    # PositionManager keeps a quantity 0 row after a position is closed; only open positions are exposure.
    3.times { |i| create(:paper_position, account_id: account_id, symbol: "CLOSED#{i}", quantity: 0) }
    expect(validator.evaluate(account_id, signal)).to eq(:passed)
  end

  it 'counts only open rows when closed rows are mixed in' do
    stub_const('Risk::PositionLimitValidator::MAX_POSITIONS', 3)
    2.times { |i| create(:paper_position, account_id: account_id, symbol: "OPEN#{i}", quantity: 1) }
    3.times { |i| create(:paper_position, account_id: account_id, symbol: "CLOSED#{i}", quantity: 0) }
    expect(validator.evaluate(account_id, signal)).to eq(:passed)
    create(:paper_position, account_id: account_id, symbol: 'OPEN2', quantity: 1)
    expect(validator.evaluate(account_id, signal)).to eq(:POSITION_LIMIT_REJECTED)
  end
end
