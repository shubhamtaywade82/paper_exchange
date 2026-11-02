require 'rails_helper'

RSpec.describe Backtest::IntentValidator do
  let(:window_start) { Time.utc(2026, 11, 2, 3, 45) }
  let(:window_end) { Time.utc(2026, 11, 2, 10, 0) }
  let(:equity) do
    Backtest::Contract.new(symbol: 'RELIANCE', instrument_type: 'EQUITY', currency: 'INR',
      timeframe: '5m', first_bar_at: window_start, last_bar_at: window_end)
  end
  let(:option) do
    Backtest::Contract.new(symbol: 'NIFTY', instrument_type: 'OPTIDX', option_type: 'CE',
      strike_price: BigDecimal('24000'), expiry_date: Date.new(2026, 11, 3),
      currency: 'INR', timeframe: '5m', first_bar_at: window_start, last_bar_at: window_end)
  end

  # Accepts an intent as a positional hash or as bare keywords.
  def validate(raw = {}, contract: equity, at: window_start, lot_size: BigDecimal('1'), **fields)
    described_class.call(raw.merge(fields), contract: contract, at: at, lot_size: lot_size)
  end

  it 'normalizes a valid buy with a stop-loss' do
    intent = validate(action: 'buy', stop_loss: '95', take_profit: '110', quantity: '10')

    expect(intent).to include(action: 'buy', side: 'buy', order_kind: 'market', quantity: BigDecimal('10'))
    expect(intent[:stop_loss]).to eq(BigDecimal('95'))
  end

  it 'rejects an opening order without a protective stop-loss' do
    expect { validate(action: 'buy') }.to raise_error(described_class::Invalid, 'stop_loss_required')
  end

  it 'rejects writing an option (a sell that opens a position)' do
    expect { validate({ action: 'sell', stop_loss: '130' }, contract: option) }
      .to raise_error(described_class::Invalid, 'options_buy_only')
  end

  it 'allows buying an option that has not expired' do
    expect(validate({ action: 'buy', stop_loss: '90' }, contract: option)).to include(side: 'buy')
  end

  it 'rejects opening anything on a contract after its expiry date' do
    expect { validate({ action: 'buy', stop_loss: '90' }, contract: option, at: Time.utc(2026, 11, 4, 4, 0)) }
      .to raise_error(described_class::Invalid, 'contract_expired')
  end

  it 'rejects a quantity that is not a whole multiple of the lot size' do
    expect { validate({ action: 'buy', stop_loss: '95', quantity: '7' }, lot_size: BigDecimal('5')) }
      .to raise_error(described_class::Invalid, 'quantity_not_lot_multiple')
  end

  it 'accepts a quantity that is a multiple of the lot size' do
    intent = validate({ action: 'buy', stop_loss: '95', quantity: '10' }, lot_size: BigDecimal('5'))

    expect(intent[:quantity]).to eq(BigDecimal('10'))
  end

  it 'requires a price for a bounded (limit) order' do
    expect { validate(action: 'buy', order_kind: 'bounded', stop_loss: '95') }
      .to raise_error(described_class::Invalid, 'bounded_requires_price')
  end

  it 'requires a trigger price for a stop order' do
    expect { validate(action: 'buy', order_kind: 'stop_loss', stop_loss: '95') }
      .to raise_error(described_class::Invalid, 'stop_loss_requires_trigger_price')
  end

  it 'rejects an unknown action and an unknown order kind' do
    expect { validate(action: 'hodl') }.to raise_error(described_class::Invalid, 'unknown_action')
    expect { validate(action: 'buy', order_kind: 'iceberg', stop_loss: '95') }
      .to raise_error(described_class::Invalid, 'unknown_order_kind')
  end

  it 'treats close as needing no stop-loss' do
    expect(validate(action: 'close')).to include(action: 'close', quantity: nil, tag: nil)
  end
end
