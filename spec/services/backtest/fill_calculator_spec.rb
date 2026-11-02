require 'rails_helper'

RSpec.describe Backtest::FillCalculator do
  def d(value)
    BigDecimal(value.to_s)
  end

  describe '.at_open' do
    it 'fills a market order at the open, adversely by slippage on each side' do
      buy = described_class.at_open(kind: 'market', side: 'buy', price: nil, trigger_price: nil, open: d(100), slippage_bps: d(10))
      sell = described_class.at_open(kind: 'market', side: 'sell', price: nil, trigger_price: nil, open: d(100), slippage_bps: d(10))

      expect(buy).to eq(d('100.1'))
      expect(sell).to eq(d('99.9'))
    end

    it 'fills a buy limit at the open when the open is already through the limit (price improvement)' do
      fill = described_class.at_open(kind: 'bounded', side: 'buy', price: d(101), trigger_price: nil, open: d(100), slippage_bps: d(50))

      expect(fill).to eq(d(100))
    end

    it 'does not fill a buy limit while the open is above it' do
      fill = described_class.at_open(kind: 'bounded', side: 'buy', price: d(99), trigger_price: nil, open: d(100), slippage_bps: d(0))

      expect(fill).to be_nil
    end

    it 'fills a sell stop at the open when the open gaps through the trigger, not at the trigger' do
      fill = described_class.at_open(kind: 'stop_loss', side: 'sell', price: nil, trigger_price: d(95), open: d(94), slippage_bps: d(0))

      expect(fill).to eq(d(94))
    end

    it 'does not trigger a sell stop while the open is above the trigger' do
      fill = described_class.at_open(kind: 'stop_loss', side: 'sell', price: nil, trigger_price: d(95), open: d(96), slippage_bps: d(0))

      expect(fill).to be_nil
    end
  end

  describe '.intrabar' do
    it 'fills a buy limit at its limit price when the bar low reaches it' do
      fill = described_class.intrabar(kind: 'bounded', side: 'buy', price: d('99.5'), trigger_price: nil,
        high: d(101), low: d(99), slippage_bps: d(50))

      expect(fill).to eq(d('99.5'))
    end

    it 'does not fill a buy limit the bar never trades down to' do
      fill = described_class.intrabar(kind: 'bounded', side: 'buy', price: d('99.5'), trigger_price: nil,
        high: d(101), low: d('99.6'), slippage_bps: d(0))

      expect(fill).to be_nil
    end

    it 'fills a sell stop at its trigger, adversely by slippage' do
      fill = described_class.intrabar(kind: 'stop_loss', side: 'sell', price: nil, trigger_price: d(95),
        high: d(100), low: d(94), slippage_bps: d(100))

      expect(fill).to eq(d('94.05'))
    end

    it 'fills a buy stop at its trigger when the bar high reaches it' do
      fill = described_class.intrabar(kind: 'stop_loss', side: 'buy', price: nil, trigger_price: d(103),
        high: d(105), low: d(99), slippage_bps: d(0))

      expect(fill).to eq(d(103))
    end

    it 'never rests a market order' do
      fill = described_class.intrabar(kind: 'market', side: 'buy', price: nil, trigger_price: nil,
        high: d(105), low: d(99), slippage_bps: d(0))

      expect(fill).to be_nil
    end
  end
end
