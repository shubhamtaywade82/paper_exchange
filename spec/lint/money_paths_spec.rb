require 'rails_helper'

# Guards the money-path invariants (MULTI_MARKET_SPEC §4, I1 and I2).
#
# Float money (I1): a Float is a binary approximation, so a conversion in money
# code is a rounding error waiting to be booked. The counts below are a RATCHET:
# each file may hold at most this many `.to_f` conversions. Lower a count when
# its file is fixed. A count never rises; a new file starts at zero.
#
# Wall-clock time (I2): financial timestamps come from Clock.now. A call to
# Time.now, Time.current or Date.today in money code is refused.
RSpec.describe 'money paths' do
  MONEY_GLOBS = %w[
    app/services/exchange/**/*.rb
    app/services/ledger/**/*.rb
    app/services/risk/**/*.rb
    app/services/charges/**/*.rb
    app/services/markets/**/*.rb
    app/services/backtest/tick/**/*.rb
    app/services/backtest/tick.rb
    app/models/paper_exchange/*.rb
    app/models/position_protection.rb
    app/models/charge_rule.rb
    app/jobs/funding_job.rb
    app/jobs/protection_monitor_job.rb
    app/jobs/option_expiry_job.rb
  ].freeze

  # Market-data mappers convert provider JSON to numbers; they are not money.
  EXCLUDED = /_catalog\.rb\z/

  # The remaining conversions, each with the reason it is still there.
  FLOAT_RATCHET = {
    'app/jobs/funding_job.rb' => 4,
    'app/jobs/option_expiry_job.rb' => 4,
    'app/jobs/protection_monitor_job.rb' => 3,
    'app/models/position_protection.rb' => 12,         # trailing-stop arithmetic, next to decimal columns
    'app/services/exchange/fill_engine.rb' => 1,        # the presentation copy of charges (jsonb)
    'app/services/exchange/matching_engine.rb' => 4,    # limit and trigger comparisons against Float quotes
    'app/services/exchange/matching_worker.rb' => 8,    # limit and trigger comparisons against Float quotes
    'app/services/exchange/paper_exchange.rb' => 2,     # settlement_price finiteness check (validation)
    'app/services/exchange/slippage_engine.rb' => 1,    # negative-price check (validation)
    'app/services/risk/liquidation_engine.rb' => 3,     # liquidation comparisons against Float marks
    'app/services/risk/max_drawdown_validator.rb' => 3  # equity peak comparison
  }.freeze

  # `Time.current` and friends. The one exemption is when a quote arrived, which
  # is wall-clock by definition and is not used for any financial figure.
  WALL_CLOCK = /\bTime\.(now|current)\b|\bDate\.(today|current)\b|\bTime\.zone\.now\b/
  WALL_CLOCK_EXEMPT = { 'app/services/exchange/matching_worker.rb' => 1 }.freeze

  def money_files
    MONEY_GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }
      .reject { |path| path.match?(EXCLUDED) }
      .map { |path| path.delete_prefix("#{Rails.root}/") }
      .sort
  end

  def count(path, pattern)
    File.read(Rails.root.join(path), encoding: 'UTF-8').scan(pattern).size
  end

  it 'scans a non-empty money-path file set' do
    expect(money_files.size).to be >= 30
  end

  it 'holds each file to its float-conversion ratchet' do
    over = money_files.filter_map do |path|
      allowed = FLOAT_RATCHET.fetch(path, 0)
      actual = count(path, /\.to_f\b/)
      "#{path}: #{actual} > #{allowed}" if actual > allowed
    end

    expect(over).to be_empty, "float conversions added to money code (use BigDecimal):\n  #{over.join("\n  ")}"
  end

  it 'has no ratchet entry that is out of date or for a file outside the scan' do
    stale = FLOAT_RATCHET.filter_map do |path, allowed|
      actual = count(path, /\.to_f\b/)
      "#{path}: ratchet #{allowed} but only #{actual}; lower it" if actual < allowed
    end

    expect(stale).to be_empty, "ratchet can be lowered:\n  #{stale.join("\n  ")}"
  end

  it 'refuses a wall-clock call in money code, except the one exempt call' do
    offenders = money_files.filter_map do |path|
      actual = count(path, WALL_CLOCK)
      allowed = WALL_CLOCK_EXEMPT.fetch(path, 0)
      "#{path}: #{actual} > #{allowed}" if actual > allowed
    end

    expect(offenders).to be_empty, "wall-clock calls in money code (use Clock.now):\n  #{offenders.join("\n  ")}"
  end

  it 'keeps the decimal-only replay primitives free of float conversions' do
    tick = money_files.select { |path| path.start_with?('app/services/backtest/tick') }

    expect(tick).not_to be_empty
    expect(tick.sum { |path| count(path, /\.to_f\b/) }).to eq(0)
  end
end
