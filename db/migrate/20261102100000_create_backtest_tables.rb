# Backtesting engine storage.
#
#   backtest_datasets  one immutable OHLC series for one instrument + timeframe
#   backtest_bars      the bars of a dataset (OHLC integrity enforced in the DB)
#   backtest_runs      one simulated run: strategy, config, status, metrics,
#                      equity curve. Each run owns a paper account
#                      (`account_id`) so every fill, order, position and
#                      ledger entry is isolated and reconcilable.
#   backtest_trades    closed round-trip trades derived from the run's fills
#
# Money columns follow the repo rule: decimal(36, 18), never float.
class CreateBacktestTables < ActiveRecord::Migration[8.1]
  MONEY = { precision: 36, scale: 18 }.freeze

  def change
    create_table :backtest_datasets do |t|
      t.string :name, null: false
      t.string :symbol, null: false
      t.string :venue, null: false, default: "paper"
      t.string :instrument_type, null: false
      t.string :currency, null: false
      t.string :timeframe, null: false
      t.string :option_type
      t.decimal :strike_price, **MONEY
      t.date :expiry_date
      t.integer :bars_count, null: false, default: 0
      t.datetime :first_bar_at
      t.datetime :last_bar_at
      t.string :fingerprint, null: false
      t.timestamps
    end
    add_index :backtest_datasets, :fingerprint
    add_index :backtest_datasets, :created_at

    create_table :backtest_bars do |t|
      t.references :backtest_dataset, null: false, foreign_key: true
      t.datetime :bar_at, null: false
      t.decimal :open, null: false, **MONEY
      t.decimal :high, null: false, **MONEY
      t.decimal :low, null: false, **MONEY
      t.decimal :close, null: false, **MONEY
      t.decimal :volume, null: false, default: 0, **MONEY
    end
    add_index :backtest_bars, %i[backtest_dataset_id bar_at], unique: true
    add_check_constraint :backtest_bars,
      "low > 0 AND high >= low AND high >= open AND high >= close AND low <= open AND low <= close",
      name: "backtest_bars_ohlc_valid"
    add_check_constraint :backtest_bars, "volume >= 0", name: "backtest_bars_volume_non_negative"

    create_table :backtest_runs do |t|
      t.string :name, null: false
      t.references :backtest_dataset, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :strategy_key, null: false
      t.jsonb :strategy_params, null: false, default: {}
      t.decimal :initial_capital, null: false, **MONEY
      t.integer :leverage, null: false, default: 1
      t.jsonb :sizing, null: false, default: {}
      t.decimal :slippage_bps, null: false, default: 0, **MONEY
      t.decimal :lot_size, null: false, default: 1, **MONEY
      t.boolean :risk_gate, null: false, default: true
      t.string :account_id, null: false
      t.jsonb :metrics, null: false, default: {}
      t.jsonb :equity_curve, null: false, default: []
      t.jsonb :diagnostics, null: false, default: {}
      t.integer :bars_processed, null: false, default: 0
      t.text :failure_reason
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :backtest_runs, :account_id, unique: true
    add_index :backtest_runs, :status
    add_index :backtest_runs, :created_at

    create_table :backtest_trades do |t|
      t.references :backtest_run, null: false, foreign_key: true
      t.integer :sequence, null: false
      t.string :symbol, null: false
      t.string :instrument_type, null: false
      t.string :option_type
      t.decimal :strike_price, **MONEY
      t.date :expiry_date
      t.string :direction, null: false
      t.decimal :quantity, null: false, **MONEY
      t.datetime :entry_at, null: false
      t.decimal :entry_price, null: false, **MONEY
      t.datetime :exit_at, null: false
      t.decimal :exit_price, null: false, **MONEY
      t.decimal :gross_pnl, null: false, **MONEY
      t.decimal :commission, null: false, **MONEY
      t.decimal :net_pnl, null: false, **MONEY
      t.decimal :return_pct, null: false, **MONEY
      t.integer :bars_held, null: false, default: 0
      t.string :exit_reason, null: false
      t.bigint :entry_order_id
      t.bigint :exit_order_id
      t.timestamps
    end
    add_index :backtest_trades, %i[backtest_run_id sequence], unique: true
    add_index :backtest_trades, %i[backtest_run_id entry_at]
  end
end
