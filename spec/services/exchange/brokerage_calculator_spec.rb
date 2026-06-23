require 'rails_helper'

RSpec.describe Exchange::BrokerageCalculator, type: :service do
  let(:calculator) { described_class.new }

  describe '.for' do
    it 'calculates charges for equity' do
      charges = calculator.for(trade_price: 100.0, quantity: 10, side: 'buy', symbol: 'RELIANCE', instrument_type: 'EQUITY')
      expect(charges).to have_key(:total_charges)
      expect(charges[:total_charges]).to be > 0
    end

    it 'applies higher STT for options' do
      opt = calculator.for(trade_price: 100.0, quantity: 10, side: 'buy', symbol: 'NIFTY', instrument_type: 'OPTIDX')
      eq = calculator.for(trade_price: 100.0, quantity: 10, side: 'buy', symbol: 'RELIANCE', instrument_type: 'EQUITY')
      expect(opt[:stt]).to be > eq[:stt]
    end
  end
end
