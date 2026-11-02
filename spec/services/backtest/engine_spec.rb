require 'rails_helper'

# End-to-end runs through the real exchange, margin, ledger and fee code.
# Each scenario is a short, hand-checkable bar series. Expected prices are
# derived from the bar path rules in Backtest::FillCalculator.
RSpec.describe Backtest::Engine, type: :service do
  def run_signal!(ohlc, signals:, dataset_options: {}, **run_options)
    dataset = create_dataset!(ohlc, **dataset_options)
    run = create_run!(dataset, strategy: signal_replay(*signals), **run_options)
    execute_run!(run)
  end

  def entry_order_for(run)
    PaperExchange::PaperOrder.where(account_id: run.account_id, status: 'filled').order(:id).first
  end

  let(:flat_bar) { [ 100, 101, 99, 100 ] }

  describe 'take-profit exit inside the bar' do
    let(:ohlc) do
      [
        [ 100, 101, 99, 100 ],
        [ 100, 102, 99, 101 ],
        [ 101, 103, 100, 102 ],  # signal decided at this bar's close
        [ 102, 111, 101, 110 ],  # fills at 102 open; high 111 reaches the 110 target
        [ 110, 111, 109, 110 ]
      ]
    end

    let(:run) do
      run_signal!(ohlc, signals: [ { ts: inside_bar(2), action: 'buy', quantity: 10, stop_loss: 95, take_profit: 110 } ])
    end

    it 'completes with one winning trade filled at the next open and exited at the target' do
      expect(run.status).to eq('completed')
      expect(run.trades.count).to eq(1)

      trade = run.trades.sole
      expect(trade.direction).to eq('long')
      expect(trade.entry_price).to eq(102)
      expect(trade.exit_price).to eq(110)
      expect(trade.exit_reason).to eq('take_profit')
      expect(trade.gross_pnl).to eq(80)
      expect(trade.commission).to be > 0
      expect(trade.net_pnl).to eq(trade.gross_pnl - trade.commission)
    end

    it 'agrees with the ledger on realized P&L and fees, and does not drift on reconciliation' do
      expect_ledger_to_match_trades(run)
      expect_no_ledger_drift(run)
    end

    it 'stamps orders and fills with bar time, not wall-clock time' do
      entry = entry_order_for(run)

      expect(entry.placed_at).to eq(bar_time(3))
      expect(entry.filled_at).to eq(bar_time(3))
      expect(run.trades.sole.entry_at).to eq(bar_time(3))
    end

    it 'records the equity curve with one point per bar, starting at the initial capital' do
      expect(run.equity_curve.size).to eq(ohlc.size)
      expect(run.equity_curve.first[1]).to eq('10000.0')
      expect(run.metrics['net_profit']).to eq(run.trades.sole.net_pnl.to_f.round(8))
    end
  end

  describe 'stop-loss exits' do
    it 'fills a stop-loss hit within the bar at the stop price' do
      run = run_signal!(
        [ flat_bar, flat_bar, [ 100, 100.5, 97, 98 ] ],
        signals: [ { ts: inside_bar(1), action: 'buy', quantity: 10, stop_loss: 98, take_profit: 110 } ]
      )

      trade = run.trades.sole
      expect(trade.exit_price).to eq(98)
      expect(trade.exit_reason).to eq('stop_loss')
      expect(trade.gross_pnl).to eq(-20)
      expect(PaperExchange::PaperOrder.where(account_id: run.account_id, status: 'open')).to be_empty
    end

    it 'fills at the open when the bar gaps through the stop, not at the stop' do
      run = run_signal!(
        [ flat_bar, flat_bar, flat_bar, [ 94, 95, 93, 94 ] ],
        signals: [ { ts: inside_bar(1), action: 'buy', quantity: 10, stop_loss: 98 } ]
      )

      trade = run.trades.sole
      expect(trade.exit_price).to eq(94)
      expect(trade.exit_reason).to eq('stop_loss')
      expect(trade.gross_pnl).to eq(-60)
    end

    it 'sizes the position so a stop-out loses exactly the configured share of equity' do
      # Equity 10,000 at 1% risk = 100 at risk. Entry 100, stop 95: distance 5, so 20 shares.
      run = run_signal!(
        [ flat_bar, flat_bar, [ 100, 100.5, 94, 95 ] ],
        signals: [ { ts: inside_bar(1), action: 'buy', stop_loss: 95 } ],
        sizing: { type: 'risk_percent', risk_percent: 1 }
      )

      trade = run.trades.sole
      expect(trade.quantity).to eq(20)
      expect(trade.exit_reason).to eq('stop_loss')
      expect(trade.gross_pnl).to eq(-100)
    end

    it 'lets the stop win when the same bar reaches both the stop and the target (adverse-first)' do
      run = run_signal!(
        [ flat_bar, flat_bar, [ 100, 112, 97, 100 ] ],
        signals: [ { ts: inside_bar(1), action: 'buy', quantity: 10, stop_loss: 98, take_profit: 110 } ]
      )

      expect(run.trades.sole.exit_reason).to eq('stop_loss')
      expect(run.trades.sole.exit_price).to eq(98)
    end
  end

  describe 'resting limit orders' do
    it 'rests a buy limit above the open and fills it at the limit when the bar trades down to it' do
      run = run_signal!(
        [ flat_bar, [ 100, 101, 98.5, 100 ], [ 101, 111, 100, 110 ] ],
        signals: [ { ts: inside_bar(0), action: 'buy', order_kind: 'bounded', price: 99, quantity: 10,
                     stop_loss: 95, take_profit: 110 } ]
      )

      trade = run.trades.sole
      expect(trade.entry_price).to eq(99)
      expect(trade.exit_price).to eq(110)
      expect(trade.exit_reason).to eq('take_profit')
      expect(trade.gross_pnl).to eq(110)
    end

    it 'cancels a limit that never triggers at end of data and releases its margin' do
      run = run_signal!(
        [ flat_bar, flat_bar, flat_bar ],
        signals: [ { ts: inside_bar(0), action: 'buy', order_kind: 'bounded', price: 90, quantity: 10, stop_loss: 85 } ],
        initial_capital: 10_000
      )

      expect(run.trades).to be_empty
      expect(run.diagnostics['cancelled_at_end']).to eq(1)
      account = Account.find_by!(account_id: run.account_id)
      expect(account.locked_margin).to eq(0)
      expect(account.available_balance).to eq(10_000)
    end
  end

  describe 'rejections and the risk gate' do
    it 'counts an unaffordable entry as an insufficient-margin rejection instead of failing the run' do
      run = run_signal!(
        [ flat_bar, flat_bar, flat_bar ],
        signals: [ { ts: inside_bar(0), action: 'buy', quantity: 10, stop_loss: 95 } ],
        initial_capital: 100
      )

      expect(run.status).to eq('completed')
      expect(run.trades).to be_empty
      expect(run.diagnostics['rejected_intents']).to eq('insufficient_margin' => 1)
      expect(run.diagnostics['risk_rejections']).to eq(0)
    end

    it 'counts an entry the risk gate refuses when its notional exceeds the position cap' do
      # 6000 x 100 = 600k notional, above MAX_POSITION_VALUE (500k). The margin lock passes (1M available).
      run = run_signal!(
        [ flat_bar, flat_bar, flat_bar ],
        signals: [ { ts: inside_bar(0), action: 'buy', quantity: 6000, stop_loss: 95 } ],
        initial_capital: 1_000_000
      )

      expect(run.diagnostics['rejected_intents']).to eq('risk_gate' => 1)
      expect(run.diagnostics['risk_rejections']).to eq(1)
      expect(run.trades).to be_empty
    end

    it 'with the risk gate disabled, the same over-cap entry is placed' do
      run = run_signal!(
        [ flat_bar, flat_bar, flat_bar ],
        signals: [ { ts: inside_bar(0), action: 'buy', quantity: 6000, stop_loss: 95 } ],
        initial_capital: 1_000_000,
        risk_gate: false
      )

      expect(run.diagnostics['rejected_intents']).to eq({})
      expect(run.diagnostics['open_position_at_end']).to include('quantity' => '6000.0')
    end

    it 'never opens a second position while one is open (pyramiding disabled)' do
      run = run_signal!(
        [ flat_bar, flat_bar, flat_bar, flat_bar ],
        signals: [
          { ts: inside_bar(0), action: 'buy', quantity: 10, stop_loss: 95 },
          { ts: inside_bar(1), action: 'buy', quantity: 10, stop_loss: 95 }
        ]
      )

      expect(run.diagnostics['rejected_intents']).to eq('pyramiding_disabled' => 1)
      expect(run.trades).to be_empty
      expect(run.diagnostics['open_position_at_end']).to include('side' => 'long', 'quantity' => '10.0')
    end
  end

  describe 'option contracts' do
    let(:option_bars) do
      [
        { bar_at: '2026-11-02T03:45:00Z', open: 100, high: 101, low: 99, close: 100, volume: 1 },
        { bar_at: '2026-11-02T03:50:00Z', open: 100, high: 101, low: 99, close: 100, volume: 1 },
        { bar_at: '2026-11-03T03:45:00Z', open: 100, high: 101, low: 99, close: 100, volume: 1 }
      ]
    end

    it 'fails the run, rather than report a result, when a position is still open after expiry' do
      dataset = Backtest::DatasetManager.create!(
        name: 'nifty ce', symbol: 'NIFTY', instrument_type: 'OPTIDX', option_type: 'CE',
        strike_price: '24000', expiry_date: '2026-11-02', timeframe: '5m', bars: option_bars
      )
      run = create_run!(dataset, strategy: signal_replay(
        { ts: '2026-11-02T03:45:30Z', action: 'buy', quantity: 1, stop_loss: 90 }
      ))

      BacktestRunJob.perform_now(run.id)

      run.reload
      expect(run.status).to eq('failed')
      expect(run.failure_reason).to include('expiry settlement is not modelled')
    end

    it 'refuses to write an option at creation time' do
      dataset = Backtest::DatasetManager.create!(
        name: 'nifty ce', symbol: 'NIFTY', instrument_type: 'OPTIDX', option_type: 'CE',
        strike_price: '24000', expiry_date: '2026-11-02', timeframe: '5m', bars: option_bars
      )

      expect {
        create_run!(dataset, strategy: signal_replay({ ts: '2026-11-02T03:45:30Z', action: 'sell', stop_loss: 130 }))
      }.to raise_error(Backtest::RunValidator::Invalid, /options_buy_only/)
    end
  end

  describe 'leveraged perpetuals' do
    it 'liquidates a long at the liquidation price when the bar low breaches it' do
      # Entry 100, leverage 10, maintenance 0.4%: liquidation = 100 * (1 - 0.1 + 0.004) = 90.4.
      run = run_signal!(
        [ flat_bar, flat_bar, [ 100, 100, 89, 95 ] ],
        signals: [ { ts: inside_bar(0), action: 'buy', quantity: 1, stop_loss: 80 } ],
        dataset_options: { symbol: 'BTCUSDT', instrument_type: 'CRYPTO_PERPETUAL', currency: 'USDT' },
        leverage: 10, initial_capital: 1_000
      )

      trade = run.trades.sole
      expect(trade.exit_reason).to eq('liquidation')
      expect(trade.exit_price).to be_within(BigDecimal('0.0001')).of(BigDecimal('90.4'))
      expect(run.status).to eq('completed')
      expect_ledger_to_match_trades(run)
    end
  end

  describe 'a systematic strategy over a longer series' do
    let(:closes) do
      [ 100, 100, 100, 95, 90, 85, 88, 92, 96, 100, 104, 108, 106, 102, 98, 94, 90, 88, 91, 95,
        99, 103, 107, 111, 108, 104, 100, 96, 92, 89, 93, 97, 101 ]
    end
    let(:ohlc) do
      closes.each_cons(2).map { |previous, close| [ previous, [ previous, close ].max + 1, [ previous, close ].min - 1, close ] }
    end
    let(:strategy) { { key: 'sma_cross', params: { fast_period: 3, slow_period: 6, stop_loss_pct: 5, take_profit_pct: 10 } } }

    it 'produces identical metrics and equity curves on repeated runs of the same definition' do
      dataset = create_dataset!(ohlc)
      run = create_run!(dataset, strategy: strategy, sizing: { type: 'percent_of_equity', percent: 50 })
      first = execute_run!(run)
      first_metrics = first.metrics.deep_dup
      first_curve = first.equity_curve.deep_dup
      first_trade_count = first.trades.count
      first_exit_reasons = first.trades.pluck(:exit_reason)

      Backtest::RunManager.reset!(run)
      second = execute_run!(run)

      expect(second.metrics).to eq(first_metrics)
      expect(second.equity_curve).to eq(first_curve)
      expect(first_trade_count).to be >= 1
      expect(first_exit_reasons).to all(be_in(%w[signal stop_loss take_profit]))
      expect_ledger_to_match_trades(second)
      expect_no_ledger_drift(second)
    end
  end

  describe 'reset' do
    let(:ohlc) do
      [ flat_bar, flat_bar, [ 100, 101, 99, 100 ], [ 102, 111, 101, 110 ], [ 110, 111, 109, 110 ] ]
    end

    it 'clears trades and orders, restores the balance, and keeps the definition for a re-run' do
      run = run_signal!(ohlc, signals: [ { ts: inside_bar(2), action: 'buy', quantity: 10, stop_loss: 95, take_profit: 110 } ])
      expect(run.trades.count).to eq(1)

      Backtest::RunManager.reset!(run)

      run.reload
      expect(run.status).to eq('pending')
      expect(run.trades).to be_empty
      expect(run.equity_curve).to eq([])
      expect(PaperExchange::PaperOrder.where(account_id: run.account_id)).to be_empty
      expect(LedgerEntry.where(account_id: run.account_id)).to be_empty
      account = Account.find_by!(account_id: run.account_id)
      expect(account.available_balance).to eq(10_000)
      expect(account.locked_margin).to eq(0)
      expect(run.strategy_params).to be_present
    end

    it 'refuses to reset a run that is still running' do
      run = create_run!(create_dataset!(ohlc), strategy: signal_replay)
      run.update!(status: 'running')

      expect { Backtest::RunManager.reset!(run) }.to raise_error(Backtest::RunManager::Conflict)
    end
  end

  describe 'isolation from live state' do
    it 'never writes simulated marks into the live mark-price cache' do
      run_signal!(
        [ flat_bar, flat_bar, [ 102, 111, 101, 110 ] ],
        signals: [ { ts: inside_bar(1), action: 'buy', quantity: 10, stop_loss: 95, take_profit: 110 } ]
      )

      expect(MarketData::MarkPriceStore.send(:local_cache)).not_to have_key('RELIANCE')
    end

    it 'leaves no session behind on the thread after a run' do
      run_signal!(
        [ flat_bar, flat_bar, flat_bar ],
        signals: [ { ts: inside_bar(0), action: 'buy', quantity: 1, stop_loss: 95 } ]
      )

      expect(Backtest::Session.current).to be_nil
    end
  end

  describe 'job lifecycle' do
    let(:run) { create_run!(create_dataset!(flat_bar.then { |b| [ b, b, b ] }), strategy: signal_replay) }

    it 'claims a pending run once; a duplicate delivery is a no-op' do
      expect(Backtest::RunManager.claim!(run)).to be(true)
      expect(Backtest::RunManager.claim!(run)).to be(false)
    end

    it 'records an unexpected failure on the run and re-raises it' do
      allow_any_instance_of(Backtest::Engine).to receive(:call).and_raise(RuntimeError, 'boom')

      expect { BacktestRunJob.perform_now(run.id) }.to raise_error(RuntimeError, 'boom')
      expect(run.reload.status).to eq('failed')
      expect(run.failure_reason).to eq('RuntimeError: boom')
    end
  end

  describe 'creation-time validation' do
    it 'refuses a signal stamped before the first bar' do
      dataset = create_dataset!([ flat_bar, flat_bar, flat_bar ])

      expect {
        create_run!(dataset, strategy: signal_replay({ ts: '2026-11-02T03:00:00Z', action: 'buy', quantity: 1, stop_loss: 95 }))
      }.to raise_error(Backtest::RunValidator::Invalid, /must be >=/)
    end

    it 'refuses a signal on the last bar, which has no next open to execute on' do
      dataset = create_dataset!([ flat_bar, flat_bar, flat_bar ])

      expect {
        create_run!(dataset, strategy: signal_replay({ ts: inside_bar(2), action: 'buy', quantity: 1, stop_loss: 95 }))
      }.to raise_error(Backtest::RunValidator::Invalid, /no next open/)
    end

    it 'refuses leverage on anything other than a perpetual' do
      dataset = create_dataset!([ flat_bar, flat_bar, flat_bar ])

      expect {
        create_run!(dataset, strategy: signal_replay, leverage: 5)
      }.to raise_error(Backtest::RunValidator::Invalid, /only supported for CRYPTO_PERPETUAL/)
    end
  end
end
