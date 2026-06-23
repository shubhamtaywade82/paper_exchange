require 'rails_helper'

RSpec.describe Exchange::SlippageEngine, type: :service do
  let(:engine) { described_class.new }

  describe '#apply' do
    it 'returns a price impacted by slippage for equity' do
      result = engine.apply(price: 100.0, quantity: 100, side: 'buy', instrument_type: 'EQUITY')
      expect(result).to be > 100.0
    end

    it 'applies higher impact for options' do
      equity_impact = engine.apply(price: 100.0, quantity: 100, side: 'buy', instrument_type: 'EQUITY')
      option_impact = engine.apply(price: 100.0, quantity: 100, side: 'buy', instrument_type: 'OPTIDX')
      expect(option_impact).to be > equity_impact
    end
  end
end
