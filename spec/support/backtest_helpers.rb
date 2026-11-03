# Shared fixtures for the backtesting specs. Bars are built from a compact
# [open, high, low, close] list; the first bar opens at 09:15 IST.
module BacktestHelpers
  IST_OPEN_UTC = Time.utc(2026, 11, 2, 3, 45).freeze
  BAR_SECONDS = 300

  def bar_time(index)
    IST_OPEN_UTC + index * BAR_SECONDS
  end

  # Timestamp that falls inside bar `index` (after its open, before the next bar).
  def inside_bar(index)
    (bar_time(index) + 60).iso8601
  end

  def bars_from(ohlc, start: IST_OPEN_UTC, step: BAR_SECONDS)
    ohlc.each_with_index.map do |(open, high, low, close), i|
      { bar_at: (start + i * step).iso8601, open: open, high: high, low: low, close: close, volume: 1_000 }
    end
  end

  def create_dataset!(ohlc, **overrides)
    Backtest::DatasetManager.create!(
      { name: "spec dataset", symbol: "RELIANCE", instrument_type: "EQUITY", timeframe: "5m", bars: bars_from(ohlc) }
        .merge(overrides)
    )
  end

  def create_run!(dataset, strategy:, sizing: { type: "fixed", quantity: 10 }, **overrides)
    payload = {
      dataset_id: dataset.id,
      name: "spec run",
      strategy: strategy,
      sizing: sizing,
      initial_capital: 10_000
    }.merge(overrides)
    Backtest::Run.create!(Backtest::RunValidator.call(payload))
  end

  # Runs the engine synchronously, the same way BacktestRunJob does.
  def execute_run!(run)
    expect(Backtest::RunManager.claim!(run)).to be(true)
    Backtest::Engine.new(run.reload).call
    run.reload
  end

  def signal_replay(*signals)
    { key: "signal_replay", params: { signals: signals } }
  end

  # Ledger must agree with the trade records: realized P&L and fees.
  def expect_ledger_to_match_trades(run)
    realized = LedgerEntry.where(account_id: run.account_id, event_type: "REALIZED_PNL").sum("credit - debit")
    fees = LedgerEntry.where(account_id: run.account_id, event_type: "FEE").sum(:debit)
    expect(realized.to_d).to be_within(BigDecimal("0.0001")).of(run.trades.sum(:gross_pnl))
    expect(fees.to_d).to be_within(BigDecimal("0.0001")).of(run.trades.sum(:commission))
  end

  # Replaying the ledger must not change the account: no drift adjustments.
  def expect_no_ledger_drift(run)
    account = Account.find_by!(account_id: run.account_id)
    Ledger::Reconciler.reconcile_account!(account)
    expect(LedgerEntry.where(account_id: run.account_id, event_type: "ADJUSTMENT")).to be_empty
  end
end

RSpec.configure do |config|
  config.include BacktestHelpers
end
