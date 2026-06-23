require 'rails_helper'

RSpec.describe Risk::MarginValidator, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:signal) { instance_double('Strategy::Signal', to_h: { symbol: 'NIFTY', side: 'buy', quantity: 10 }, instrument_type: 'EQUITY') }
  let(:validator) { described_class.new }

  before { create(:account, account_id: account_id, margin: 100_000.0) }

  describe '#evaluate' do
    it 'returns :passed for reasonable trade size' do
      expect(validator.evaluate(account_id, signal)).to eq(:passed)
    end
  end
end
