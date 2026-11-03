require 'rails_helper'

# The run definition is the bot's contract: every benchmark, manifest and mode
# it sends is checked here, before any run exists.
RSpec.describe Backtest::RunValidator do
  let(:dataset) { create_dataset!([ [ 100, 101, 99, 100 ], [ 100, 101, 99, 100 ] ]) }
  let(:base) { { dataset_id: dataset.id, name: 'run', mode: 'external' } }

  def invalid_reasons(payload)
    described_class.call(payload)
    raise 'expected the run definition to be refused'
  rescue described_class::Invalid => e
    e.errors.join(' | ')
  end

  it 'names the field the schema rejects' do
    expect(invalid_reasons(base.except(:dataset_id))).to include('dataset_id')
  end

  it 'refuses an engine run without a strategy' do
    expect(invalid_reasons(base.merge(mode: 'engine', sizing: { type: 'fixed', quantity: 1 })))
      .to include('mode engine needs a strategy')
  end

  it 'refuses a benchmark that is not one of the known thresholds' do
    expect(invalid_reasons(base.merge(benchmarks: { make_money: 5 })))
      .to include('benchmarks.make_money is not a known benchmark')
  end

  it 'refuses a numeric benchmark that is not a number' do
    expect(invalid_reasons(base.merge(benchmarks: { min_trades: 'lots' })))
      .to include('benchmarks.min_trades must be a finite number')
  end

  it 'refuses beat_buy_and_hold unless it is true or false' do
    expect(invalid_reasons(base.merge(benchmarks: { beat_buy_and_hold: 'yes' })))
      .to include('benchmarks.beat_buy_and_hold must be true or false')
  end

  it 'refuses a strategy on an external run, which decides over the API' do
    expect(invalid_reasons(base.merge(strategy: { key: 'sma_cross', params: {} })))
      .to include('mode external takes no strategy')
  end

  it 'refuses a manifest above the size limit' do
    expect(invalid_reasons(base.merge(manifest: { notes: 'x' * (described_class::MANIFEST_MAX_BYTES + 1) })))
      .to include('bytes; the limit is')
  end

  it 'stores the declared thresholds as strings and the manifest with string keys' do
    attrs = described_class.call(base.merge(
      benchmarks: { min_trades: 5, beat_buy_and_hold: true },
      manifest: { strategy: 'alma', params: { fast: 9 } }
    ))

    expect(attrs[:benchmarks]).to eq('min_trades' => '5.0', 'beat_buy_and_hold' => true)
    expect(attrs[:manifest]).to eq('strategy' => 'alma', 'params' => { 'fast' => 9 })
    expect(attrs[:mode]).to eq('external')
  end
end
