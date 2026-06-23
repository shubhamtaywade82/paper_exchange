require 'rails_helper'

RSpec.describe Exchange::BrokerageCalculator, type: :service do
  let(:calculator) { described_class.new }

  describe '.calculate' do
    it 'calculates charges for equity' do
      charges = calculator.calculate(trade_price: 100.0, quantity: 10, side: 'buy', symbol: 'RELIANCE', instrument_type: 'EQUITY')
      expect(charges).to have_key(:total)
      expect(charges[:total]).to be > 0
    end

    it 'charges higher STT on options sell vs equity sell' do
      opt_sell = calculator.calculate(trade_price: 100.0, quantity: 10, side: 'sell', symbol: 'NIFTY', instrument_type: 'OPTIDX')
      eq_sell = calculator.calculate(trade_price: 100.0, quantity: 10, side: 'sell', symbol: 'RELIANCE', instrument_type: 'EQUITY')
      expect(opt_sell[:stt]).to be > eq_sell[:stt]
    end
  end
end
