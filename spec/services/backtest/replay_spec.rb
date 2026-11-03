require 'rails_helper'

# The step-wise replay that both drivers use: queued intents execute at the next
# open, protective legs fire on later bars, and a run finishes once, cleanly.
RSpec.describe Backtest::Replay, type: :service do
  let(:flat) { [ 100, 101, 99, 100 ] }

  def external_run!(ohlc, **overrides)
    dataset = create_dataset!(ohlc)
    attrs = { dataset_id: dataset.id, name: 'external', mode: 'external', initial_capital: 10_000 }.merge(overrides)
    Backtest::RunManager.create!(Backtest::RunValidator.call(attrs))
  end

  def api_order(run, **attrs)
    described_class.new(run).queue_api_order!({ symbol: 'RELIANCE', instrument_type: 'EQUITY' }.merge(attrs))
  end

  it 'lets a stop-loss placed by the bot fire on a later bar, and labels the exit as a stop' do
    run = external_run!([ flat, flat, [ 100, 100.5, 97, 98 ], flat ])
    api_order(run, side: 'buy', quantity: 10, order_type: 'market', stop_loss: 98, take_profit: 110)

    replay = described_class.new(run)
    4.times { replay.advance! } # the fourth, last bar finishes the run and stores its trades
    run.reload

    expect(run.trades.sole).to have_attributes(exit_reason: 'stop_loss', exit_price: 98)
  end

  it 'rejects a client_order_id the run has already used' do
    run = external_run!([ flat, flat, flat ])
    api_order(run, side: 'buy', quantity: 1, order_type: 'market', stop_loss: 95, client_order_id: 'entry-1')

    expect { api_order(run, side: 'buy', quantity: 1, order_type: 'market', stop_loss: 95, client_order_id: 'entry-1') }
      .to raise_error(described_class::Invalid, /already used/)
  end

  it 'records an intent the bot queued after the last bar as unexecuted' do
    run = external_run!([ flat, flat ])
    replay = described_class.new(run)
    replay.advance!
    api_order(run, side: 'buy', quantity: 1, order_type: 'market', stop_loss: 95)
    replay.finish!(reason: 'requested')
    run.reload

    expect(run.diagnostics).to include('finished_reason' => 'requested', 'unexecuted_intents' => 1)
    expect(run.intents.sole).to have_attributes(status: 'cancelled', note: 'no_next_open')
  end

  it 'finishes early on request, keeping the metrics and an open position for the report' do
    run = external_run!([ flat, flat, flat ])
    replay = described_class.new(run)
    replay.advance!
    api_order(run, side: 'buy', quantity: 10, order_type: 'market', stop_loss: 95)
    replay.advance!
    replay.finish!

    run.reload
    expect(run).to be_completed
    expect(run.bars_processed).to eq(2)
    expect(run.diagnostics['open_position_at_end']).to include('side' => 'long', 'quantity' => '10.0')
    expect(run.metrics).to include('total_trades' => 0)
  end

  it 'refuses further bars and orders once the run is finished' do
    run = external_run!([ flat, flat ])
    replay = described_class.new(run)
    replay.advance!
    replay.advance!

    expect { replay.advance! }.to raise_error(described_class::Conflict)
    expect { api_order(run, side: 'buy', quantity: 1, order_type: 'market', stop_loss: 95) }
      .to raise_error(described_class::Conflict)
  end

  it 'stores the verdict against the benchmarks the run declared' do
    run = external_run!([ flat, flat ], benchmarks: { min_trades: 1 })
    described_class.new(run).finish!

    expect(run.reload.verdict).to include('passed' => false)
    expect(run.verdict['checks'].sole).to include('check' => 'min_trades', 'actual' => 0.0)
  end

  it 'processes exactly one bar per advance and reports only the next bar time ahead of it' do
    run = external_run!([ flat, [ 100, 110, 99, 105 ], [ 105, 106, 104, 105 ] ])

    step = described_class.new(run).advance!

    expect(step.bar.bar_at).to eq(bar_time(0))
    expect(step.next_bar_at).to eq(bar_time(1))
    expect(run.reload.bars_processed).to eq(1)
  end
end
