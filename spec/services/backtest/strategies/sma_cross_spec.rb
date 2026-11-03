require 'rails_helper'

RSpec.describe Backtest::Strategies::SmaCross, type: :service do
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

  # Accepts the definition as a hash or as keywords.
  def normalize(params = {}, contract: equity, **fields)
    described_class.normalize_params(params.merge(fields), contract: contract, lot_size: BigDecimal('1'))
  end

  describe '.normalize_params' do
    it 'refuses a slow period that is not longer than the fast period' do
      expect { normalize(fast_period: 9, slow_period: 9, stop_loss_pct: 1) }
        .to raise_error(Backtest::Strategies::InvalidParams, 'slow_period must be greater than fast_period')
    end

    it 'refuses a definition that fails the parameter schema, naming the field' do
      expect { normalize(fast_period: 9, slow_period: 21) }
        .to raise_error(Backtest::Strategies::InvalidParams, /stop_loss_pct/)
    end

    it 'refuses shorts on an option contract, which is only ever bought' do
      expect { normalize({ fast_period: 3, slow_period: 6, stop_loss_pct: 1, allow_short: true }, contract: option) }
        .to raise_error(Backtest::Strategies::InvalidParams, /allow_short is not permitted on option contracts/)
    end

    it 'refuses shorts on cash equity, which the exchange does not sell short' do
      expect { normalize({ fast_period: 3, slow_period: 6, stop_loss_pct: 1, allow_short: true }) }
        .to raise_error(Backtest::Strategies::InvalidParams, /allow_short is not permitted on cash equity/)
    end

    it 'stores the percentages as strings and defaults allow_short to false' do
      params = normalize(fast_period: 3, slow_period: 6, stop_loss_pct: 2, take_profit_pct: 4)

      expect(params).to eq(
        fast_period: 3, slow_period: 6, stop_loss_pct: '2.0', take_profit_pct: '4.0', allow_short: false
      )
    end
  end

  describe 'short entries on a perpetual, through the engine' do
    # Closes fall from 100 to 85 and recover to 105. A 2-bar fast average crosses
    # below the 3-bar slow average at the fall (short), and back above it on the
    # recovery (cover). Perpetuals can be shorted; cash equity cannot.
    let(:closes) { [ 100, 100, 100, 100, 95, 90, 85, 90, 95, 100, 105 ] }
    let(:ohlc) do
      closes.each_with_index.map do |close, i|
        open = i.zero? ? close : closes[i - 1]
        [ open, [ open, close ].max + 1, [ open, close ].min - 1, close ]
      end
    end

    it 'sells short on the cross down, covers on the cross up, and sizes from the fixed quantity' do
      dataset = create_dataset!(ohlc,
        symbol: 'BTCUSDT', instrument_type: 'CRYPTO_PERPETUAL', currency: 'USDT')
      run = create_run!(dataset,
        strategy: { key: 'sma_cross', params: { fast_period: 2, slow_period: 3, stop_loss_pct: 2, allow_short: true } },
        sizing: { type: 'fixed', quantity: 1 })

      execute_run!(run)

      trade = run.trades.sole
      # The cover is labelled with the strategy's own tag, so a report says why it exited.
      expect(trade).to have_attributes(direction: 'short', quantity: 1, exit_reason: 'sma_cross_exit')
      expect(run.status).to eq('completed')
    end
  end
end
