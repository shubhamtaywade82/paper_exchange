require 'rails_helper'

RSpec.describe Risk::PositionLimitValidator, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:signal) { instance_double('Strategy::Signal', to_h: { symbol: 'NIFTY' }, symbol: 'NIFTY') }
  let(:validator) { described_class.new }

  before { create(:account, account_id: account_id) }

  it 'passes when under limit' do
    5.times { create(:paper_position, account_id: account_id, symbol: 'NIFTY') }
    expect(validator.evaluate(account_id, signal)).to eq([:passed, validator])
  end
end
