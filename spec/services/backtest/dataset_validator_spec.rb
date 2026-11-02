require 'rails_helper'

RSpec.describe Backtest::DatasetValidator do
  let(:valid_bars) do
    [
      { bar_at: '2026-11-02T03:45:00Z', open: '100', high: '101', low: '99', close: '100.5', volume: '10' },
      { bar_at: '2026-11-02T03:50:00Z', open: '100.5', high: '102', low: '100', close: '101', volume: '12' }
    ]
  end
  let(:base) { { name: 'nifty', symbol: 'reliance', instrument_type: 'EQUITY', timeframe: '5m', bars: valid_bars } }

  def invalid_reasons(params)
    described_class.call(params)
    raise 'expected Invalid'
  rescue described_class::Invalid => e
    e.errors.join(' | ')
  end

  it 'accepts valid bars, upcases the symbol and derives the metadata' do
    result = described_class.call(base)

    expect(result[:attributes]).to include(symbol: 'RELIANCE', currency: 'INR', bars_count: 2, venue: 'paper')
    expect(result[:attributes][:first_bar_at]).to eq(Time.utc(2026, 11, 2, 3, 45))
    expect(result[:attributes][:last_bar_at]).to eq(Time.utc(2026, 11, 2, 3, 50))
  end

  it 'sorts out-of-order bars by time' do
    result = described_class.call(base.merge(bars: valid_bars.reverse))

    expect(result[:candles].map(&:bar_at)).to eq(result[:candles].map(&:bar_at).sort)
  end

  it 'produces a stable fingerprint, which changes when any price changes' do
    first = described_class.call(base)[:attributes][:fingerprint]
    again = described_class.call(base)[:attributes][:fingerprint]
    altered_bars = valid_bars.map.with_index { |bar, i| i.zero? ? bar.merge(close: '100.6') : bar }
    altered = described_class.call(base.merge(bars: altered_bars))[:attributes][:fingerprint]

    expect(first).to eq(again)
    expect(altered).not_to eq(first)
  end

  it 'parses CSV text with a header row' do
    csv = "bar_at,open,high,low,close,volume\n2026-11-02T03:45:00Z,100,101,99,100.5,10\n2026-11-02T03:50:00Z,100.5,102,100,101,12\n"
    result = described_class.call(base.except(:bars).merge(csv: csv))

    expect(result[:attributes][:bars_count]).to eq(2)
  end

  it 'rejects OHLC that is inconsistent with itself' do
    bars = valid_bars.dup
    bars[0] = bars[0].merge(high: '99.5')

    expect(invalid_reasons(base.merge(bars: bars))).to include('OHLC is inconsistent')
  end

  it 'rejects a non-positive price' do
    bars = valid_bars.dup
    bars[0] = bars[0].merge(low: '0')

    expect(invalid_reasons(base.merge(bars: bars))).to include('open/high/low/close must be finite positive numbers')
  end

  it 'rejects a timestamp without a time-zone offset' do
    bars = valid_bars.dup
    bars[0] = bars[0].merge(bar_at: '2026-11-02T09:15:00')

    expect(invalid_reasons(base.merge(bars: bars))).to include('bar_at must be epoch seconds or ISO8601 with an offset')
  end

  it 'rejects duplicate timestamps' do
    bars = valid_bars.map { |b| b.merge(bar_at: '2026-11-02T03:45:00Z') }

    expect(invalid_reasons(base.merge(bars: bars))).to include('duplicate bar_at')
  end

  it 'rejects a currency that does not match the instrument' do
    expect(invalid_reasons(base.merge(instrument_type: 'CRYPTO_PERPETUAL', currency: 'INR')))
      .to include('currency must be USDT for CRYPTO_PERPETUAL')
  end

  it 'rejects an option instrument without option_type, strike and expiry' do
    reasons = invalid_reasons(base.merge(symbol: 'NIFTY', instrument_type: 'OPTIDX'))

    expect(reasons).to include('option_type must be CE or PE for OPTIDX')
    expect(reasons).to include('strike_price is required for OPTIDX')
    expect(reasons).to include('expiry_date (YYYY-MM-DD) is required for OPTIDX')
  end

  it 'rejects an index symbol declared as an equity, which the live order rules forbid' do
    expect(invalid_reasons(base.merge(symbol: 'NIFTY', instrument_type: 'EQUITY')))
      .to include('indices trade only as FUTIDX or OPTIDX')
  end

  it 'rejects option fields on a non-option instrument' do
    expect(invalid_reasons(base.merge(option_type: 'CE')))
      .to include('option fields are only valid for option instruments')
  end

  it 'requires at least two bars' do
    expect(invalid_reasons(base.merge(bars: valid_bars.first(1)))).to include('at least 2 bars are required')
  end

  it 'rejects datasets above the configured bar limit' do
    allow(described_class).to receive(:max_bars).and_return(1)

    expect(invalid_reasons(base)).to include('too many bars')
  end
end
