require 'rails_helper'

RSpec.describe Backtest::Verdict do
  let(:metrics) do
    {
      'total_trades' => 12, 'profit_factor' => 1.65, 'max_drawdown_pct' => 4.2,
      'net_profit_pct' => 3.5, 'percent_profitable' => 58.0, 'sharpe_ratio' => 1.1,
      'equity_change_pct' => 3.5, 'buy_and_hold_return_pct' => 1.0
    }
  end

  it 'reports no verdict when no benchmarks are declared, rather than a silent pass' do
    expect(described_class.call(benchmarks: {}, metrics: metrics)).to eq(
      'passed' => nil, 'checks' => [], 'note' => 'no benchmarks declared'
    )
  end

  it 'passes when every declared threshold is met' do
    verdict = described_class.call(
      benchmarks: { 'min_trades' => '10', 'min_profit_factor' => '1.2', 'max_drawdown_pct' => '5',
                    'min_net_profit_pct' => '0', 'min_sharpe_ratio' => '0.5', 'beat_buy_and_hold' => true },
      metrics: metrics
    )

    expect(verdict['passed']).to be(true)
    expect(verdict['checks'].map { |c| c['check'] }).to include('min_trades', 'beat_buy_and_hold')
  end

  it 'fails and names the check when a threshold is missed' do
    verdict = described_class.call(benchmarks: { 'max_drawdown_pct' => '3' }, metrics: metrics)

    expect(verdict['passed']).to be(false)
    expect(verdict['checks'].sole).to include('check' => 'max_drawdown_pct', 'required' => 3.0, 'actual' => 4.2, 'passed' => false)
  end

  it 'fails a check whose metric is undefined (nil), never treats it as zero' do
    verdict = described_class.call(benchmarks: { 'min_profit_factor' => '1.0' }, metrics: metrics.merge('profit_factor' => nil))

    expect(verdict['passed']).to be(false)
  end

  it 'compares the strategy return with buy and hold when asked to beat it' do
    verdict = described_class.call(benchmarks: { 'beat_buy_and_hold' => true },
      metrics: metrics.merge('equity_change_pct' => 0.5, 'buy_and_hold_return_pct' => 4.0))

    expect(verdict['passed']).to be(false)
    expect(verdict['checks'].sole).to include('actual' => 0.5, 'benchmark' => 4.0)
  end

  it 'ignores beat_buy_and_hold when it is declared false' do
    verdict = described_class.call(benchmarks: { 'beat_buy_and_hold' => false }, metrics: metrics)

    expect(verdict['passed']).to be_nil
  end
end
