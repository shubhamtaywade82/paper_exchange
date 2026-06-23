require 'rails_helper'

RSpec.describe MarketData::TickProcessor, type: :service do
  it 'initializes' do
    expect { described_class.new }.not_to raise_error
  end
end
