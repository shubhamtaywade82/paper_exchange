require 'rails_helper'

RSpec.describe Risk::VixGate, type: :service do
  it 'allows normal vix and rejects high vix' do
    expect(described_class.allowed?(15.0)).to be true
    expect(described_class.allowed?(25.0)).to be false
    expect(described_class.allowed?(nil)).to be false
  end
end
