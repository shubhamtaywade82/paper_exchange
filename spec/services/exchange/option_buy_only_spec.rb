require 'rails_helper'

# Options are bought to open and sold only to close. A sell that is not
# reduce_only would write the option, which the platform does not support.
RSpec.describe Exchange::OrderValidator, 'options buy-only rule', type: :service do
  # Index options use an index underlying; index symbols are refused for any
  # other instrument type, so each option type gets its own underlying.
  UNDERLYING = { 'OPTIDX' => 'NIFTY', 'OPTSTK' => 'RELIANCE', 'OPTFUT' => 'CRUDEOIL', 'OPTCUR' => 'USDINR' }.freeze

  def attrs_for(instrument_type:, side:, **extra)
    {
      account_id: 'ACC-001',
      symbol: UNDERLYING.fetch(instrument_type, 'NIFTY'),
      side: side,
      quantity: 50,
      order_kind: 'market',
      instrument_type: instrument_type,
      option_type: 'CE',
      strike_price: 24_000,
      expiry_date: Date.new(2026, 11, 26)
    }.merge(extra)
  end

  %w[OPTIDX OPTSTK OPTFUT OPTCUR].each do |option_type|
    context "for #{option_type}" do
      it 'accepts a buy to open' do
        expect(described_class.call(attrs_for(instrument_type: option_type, side: 'buy'))[:side]).to eq('buy')
      end

      it 'refuses a sell that would write the option' do
        expect { described_class.call(attrs_for(instrument_type: option_type, side: 'sell')) }
          .to raise_error(Exchange::OrderValidationError, /sell must be reduce_only: options are bought to open/)
      end

      it 'refuses a sell that says reduce_only: false' do
        expect { described_class.call(attrs_for(instrument_type: option_type, side: 'sell', reduce_only: false)) }
          .to raise_error(Exchange::OrderValidationError, /must be reduce_only/)
      end

      it 'accepts a reduce_only sell, which closes a long' do
        expect(described_class.call(attrs_for(instrument_type: option_type, side: 'sell', reduce_only: true))[:reduce_only])
          .to be(true)
      end

      it 'accepts a reduce_only buy, so a legacy short can still be closed' do
        expect(described_class.call(attrs_for(instrument_type: option_type, side: 'buy', reduce_only: true))[:side])
          .to eq('buy')
      end
    end
  end

  it 'does not restrict futures: a short future is a valid order' do
    attrs = attrs_for(instrument_type: 'FUTIDX', side: 'sell', option_type: nil, strike_price: nil)
    expect(described_class.call(attrs)[:side]).to eq('sell')
  end
end
