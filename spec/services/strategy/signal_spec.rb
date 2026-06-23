require 'rails_helper'

RSpec.describe Strategy::Signal, type: :service do
  it 'builds with valid attr hash' do
    sig = described_class.new(account_id: 'A', symbol: 'NIFTY', side: 'buy', quantity: 10, instrument_type: 'FUTIDX')
    expect(sig.account_id).to eq('A')
    expect(sig.instrument_type).to eq('FUTIDX')
  end

  it 'defaults instrument_type to EQUITY' do
    sig = described_class.new(account_id: 'A', symbol: 'RELIANCE', side: 'buy', quantity: 10)
    expect(sig.instrument_type).to eq('EQUITY')
  end

  it 'serializes to hash' do
    sig = described_class.new(account_id: 'A', symbol: 'NIFTY', side: 'buy', quantity: 10)
    expect(sig.to_h).to be_a(Hash)
  end
end
