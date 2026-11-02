# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_02_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_id", null: false
    t.decimal "available_balance", precision: 36, scale: 18, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "INR", null: false
    t.decimal "current_equity", precision: 36, scale: 18, default: "0.0", null: false
    t.decimal "locked_margin", precision: 36, scale: 18, default: "0.0", null: false
    t.decimal "margin", precision: 36, scale: 18, default: "0.0", null: false
    t.string "name", null: false
    t.boolean "simulated", default: false, null: false
    # P1-1: persisted equity high-water mark for the drawdown risk gate.
    t.decimal "max_equity_achieved", precision: 36, scale: 18, default: "0.0", null: false
    t.decimal "realized_pnl", precision: 36, scale: 18, default: "0.0", null: false
    t.decimal "unrealized_pnl", precision: 36, scale: 18, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_accounts_on_account_id", unique: true
  end

  create_table "backtest_bars", force: :cascade do |t|
    t.bigint "backtest_dataset_id", null: false
    t.datetime "bar_at", null: false
    t.decimal "open", precision: 36, scale: 18, null: false
    t.decimal "high", precision: 36, scale: 18, null: false
    t.decimal "low", precision: 36, scale: 18, null: false
    t.decimal "close", precision: 36, scale: 18, null: false
    t.decimal "volume", precision: 36, scale: 18, default: "0.0", null: false
    t.index ["backtest_dataset_id", "bar_at"], name: "index_backtest_bars_on_backtest_dataset_id_and_bar_at", unique: true
    t.index ["backtest_dataset_id"], name: "index_backtest_bars_on_backtest_dataset_id"
    t.check_constraint "low > 0::numeric AND high >= low AND high >= open AND high >= close AND low <= open AND low <= close", name: "backtest_bars_ohlc_valid"
    t.check_constraint "volume >= 0::numeric", name: "backtest_bars_volume_non_negative"
  end

  create_table "backtest_datasets", force: :cascade do |t|
    t.string "name", null: false
    t.string "symbol", null: false
    t.string "venue", default: "paper", null: false
    t.string "instrument_type", null: false
    t.string "currency", null: false
    t.string "timeframe", null: false
    t.string "option_type"
    t.decimal "strike_price", precision: 36, scale: 18
    t.date "expiry_date"
    t.integer "bars_count", default: 0, null: false
    t.datetime "first_bar_at"
    t.datetime "last_bar_at"
    t.string "fingerprint", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_backtest_datasets_on_created_at"
    t.index ["fingerprint"], name: "index_backtest_datasets_on_fingerprint"
  end

  create_table "backtest_equity_points", force: :cascade do |t|
    t.bigint "backtest_run_id", null: false
    t.datetime "bar_at", null: false
    t.decimal "equity", precision: 36, scale: 18, null: false
    t.boolean "in_market", default: false, null: false
    t.datetime "created_at", null: false
    t.index ["backtest_run_id", "bar_at"], name: "index_backtest_equity_points_on_backtest_run_id_and_bar_at", unique: true
    t.index ["backtest_run_id"], name: "index_backtest_equity_points_on_backtest_run_id"
  end

  create_table "backtest_intents", force: :cascade do |t|
    t.bigint "backtest_run_id", null: false
    t.bigint "parent_intent_id"
    t.string "source", null: false
    t.string "role", null: false
    t.string "status", default: "queued", null: false
    t.string "action", null: false
    t.string "side"
    t.string "order_kind"
    t.boolean "reduce_only", default: false, null: false
    t.decimal "quantity", precision: 36, scale: 18
    t.decimal "price", precision: 36, scale: 18
    t.decimal "trigger_price", precision: 36, scale: 18
    t.decimal "stop_loss", precision: 36, scale: 18
    t.decimal "take_profit", precision: 36, scale: 18
    t.integer "leverage", default: 1, null: false
    t.string "reason"
    t.string "client_order_id"
    t.bigint "paper_order_id"
    t.datetime "queued_at"
    t.datetime "submitted_at"
    t.text "rejection_reason"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["backtest_run_id", "client_order_id"], name: "index_backtest_intents_on_run_and_client_order_id", unique: true, where: "(client_order_id IS NOT NULL)"
    t.index ["backtest_run_id", "status"], name: "index_backtest_intents_on_backtest_run_id_and_status"
    t.index ["backtest_run_id"], name: "index_backtest_intents_on_backtest_run_id"
    t.index ["paper_order_id"], name: "index_backtest_intents_on_paper_order_id", unique: true, where: "(paper_order_id IS NOT NULL)"
    t.index ["parent_intent_id"], name: "index_backtest_intents_on_parent_intent_id"
  end

  create_table "backtest_runs", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "backtest_dataset_id", null: false
    t.string "status", default: "pending", null: false
    t.string "strategy_key", null: false
    t.jsonb "strategy_params", default: {}, null: false
    t.decimal "initial_capital", precision: 36, scale: 18, null: false
    t.integer "leverage", default: 1, null: false
    t.jsonb "sizing", default: {}, null: false
    t.decimal "slippage_bps", precision: 36, scale: 18, default: "0.0", null: false
    t.decimal "lot_size", precision: 36, scale: 18, default: "1.0", null: false
    t.boolean "risk_gate", default: true, null: false
    t.string "account_id", null: false
    t.jsonb "metrics", default: {}, null: false
    t.jsonb "diagnostics", default: {}, null: false
    t.integer "bars_processed", default: 0, null: false
    t.text "failure_reason"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "mode", default: "engine", null: false
    t.jsonb "manifest", default: {}, null: false
    t.jsonb "benchmarks", default: {}, null: false
    t.jsonb "verdict", default: {}, null: false
    t.datetime "replay_at"
    t.index ["account_id"], name: "index_backtest_runs_on_account_id", unique: true
    t.index ["backtest_dataset_id"], name: "index_backtest_runs_on_backtest_dataset_id"
    t.index ["created_at"], name: "index_backtest_runs_on_created_at"
    t.index ["status"], name: "index_backtest_runs_on_status"
  end

  create_table "backtest_trades", force: :cascade do |t|
    t.bigint "backtest_run_id", null: false
    t.integer "sequence", null: false
    t.string "symbol", null: false
    t.string "instrument_type", null: false
    t.string "option_type"
    t.decimal "strike_price", precision: 36, scale: 18
    t.date "expiry_date"
    t.string "direction", null: false
    t.decimal "quantity", precision: 36, scale: 18, null: false
    t.datetime "entry_at", null: false
    t.decimal "entry_price", precision: 36, scale: 18, null: false
    t.datetime "exit_at", null: false
    t.decimal "exit_price", precision: 36, scale: 18, null: false
    t.decimal "gross_pnl", precision: 36, scale: 18, null: false
    t.decimal "commission", precision: 36, scale: 18, null: false
    t.decimal "net_pnl", precision: 36, scale: 18, null: false
    t.decimal "return_pct", precision: 36, scale: 18, null: false
    t.integer "bars_held", default: 0, null: false
    t.string "exit_reason", null: false
    t.bigint "entry_order_id"
    t.bigint "exit_order_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["backtest_run_id", "entry_at"], name: "index_backtest_trades_on_backtest_run_id_and_entry_at"
    t.index ["backtest_run_id", "sequence"], name: "index_backtest_trades_on_backtest_run_id_and_sequence", unique: true
    t.index ["backtest_run_id"], name: "index_backtest_trades_on_backtest_run_id"
  end





  create_table "position_protections", force: :cascade do |t|
    t.bigint "paper_position_id", null: false
    t.string "account_id", null: false
    t.string "venue", null: false, default: "paper"
    t.string "instrument_id", null: false
    t.string "protection_type", null: false
    t.decimal "trigger_price", precision: 36, scale: 18
    t.decimal "trailing_distance", precision: 36, scale: 18
    t.decimal "quantity", precision: 36, scale: 18, null: false
    t.string "status", null: false, default: "active"
    t.string "oco_group_id"
    t.decimal "high_water_mark", precision: 36, scale: 18
    t.decimal "low_water_mark", precision: 36, scale: 18
    t.datetime "triggered_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_position_protections_on_account_status"
    t.index ["oco_group_id"], name: "index_position_protections_on_oco_group_id", where: "(oco_group_id IS NOT NULL)"
    t.index ["paper_position_id"], name: "index_position_protections_on_paper_position_id"
    t.index ["venue", "instrument_id", "status"], name: "index_position_protections_on_venue_instrument_status"
  end

  create_table "funding_payments", force: :cascade do |t|
    t.string "account_id", null: false
    t.decimal "amount", precision: 36, scale: 18, null: false
    t.datetime "created_at", null: false
    t.decimal "funding_rate", precision: 36, scale: 18, null: false
    t.datetime "occurred_at", null: false
    t.bigint "paper_position_id"
    t.decimal "position_notional", precision: 36, scale: 18, null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.datetime "funding_time"
    t.index ["account_id"], name: "index_funding_payments_on_account_id"
    t.index ["paper_position_id", "funding_time"], name: "index_funding_payments_dedup", unique: true, where: "(funding_time IS NOT NULL)"
    t.index ["paper_position_id"], name: "index_funding_payments_on_paper_position_id"
    t.index ["symbol", "occurred_at"], name: "index_funding_payments_on_symbol_and_occurred_at"
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.string "account_id", null: false
    t.decimal "balance_after", precision: 36, scale: 18
    t.datetime "created_at", null: false
    t.decimal "credit", precision: 36, scale: 18, default: "0.0", null: false
    t.string "currency", default: "INR", null: false
    t.decimal "debit", precision: 36, scale: 18, default: "0.0", null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "posted_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "reference_id"
    t.datetime "updated_at", null: false
    t.index ["account_id", "occurred_at", "id"], name: "index_ledger_entries_on_account_occurred_id"
    t.index ["account_id"], name: "index_ledger_entries_on_account_id"
    t.index ["event_type"], name: "index_ledger_entries_on_event_type"
    t.index ["occurred_at"], name: "index_ledger_entries_on_occurred_at"
  end

  create_table "market_structure_snapshots", force: :cascade do |t|
    t.datetime "as_of", null: false
    t.integer "bearish_fvg_count", default: 0, null: false
    t.integer "bullish_fvg_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "last_bos", default: false, null: false
    t.boolean "last_choch", default: false, null: false
    t.string "liquidity_sweep"
    t.string "order_block"
    t.string "premium_discount"
    t.string "symbol", null: false
    t.string "timeframe", default: "5m", null: false
    t.string "trend"
    t.datetime "updated_at", null: false
    t.index ["symbol", "timeframe", "as_of"], name: "index_mss_lookup"
  end

  create_table "option_snapshots", force: :cascade do |t|
    t.decimal "ask", precision: 18, scale: 2
    t.decimal "bid", precision: 18, scale: 2
    t.datetime "created_at", null: false
    t.decimal "delta", precision: 18, scale: 6
    t.date "expiry_date", null: false
    t.decimal "gamma", precision: 18, scale: 6
    t.decimal "iv", precision: 18, scale: 6
    t.decimal "ltp", precision: 18, scale: 2
    t.integer "oi", default: 0, null: false
    t.string "option_type", null: false
    t.decimal "rho", precision: 18, scale: 6
    t.datetime "snapshot_at", null: false
    t.decimal "strike_price", precision: 18, scale: 2, null: false
    t.string "symbol", null: false
    t.decimal "theta", precision: 18, scale: 6
    t.string "underlying", null: false
    t.datetime "updated_at", null: false
    t.decimal "vega", precision: 18, scale: 6
    t.integer "volume", default: 0, null: false
    t.index ["snapshot_at"], name: "index_option_snapshots_on_snapshot_at"
    t.index ["underlying", "expiry_date", "strike_price", "option_type"], name: "index_option_snapshots_lookup"
  end

  create_table "paper_exchange_orders", force: :cascade do |t|
    t.string "account_id", null: false
    t.decimal "avg_fill_price", precision: 36, scale: 18
    t.string "broker_order_id"
    t.datetime "cancelled_at"
    t.string "client_order_id"
    t.datetime "created_at", null: false
    t.string "exchange_segment"
    t.date "expiry_date"
    t.datetime "filled_at"
    t.decimal "filled_quantity", precision: 36, scale: 18, default: "0.0", null: false
    t.string "instrument_type", default: "EQUITY", null: false
    t.integer "leverage", default: 1, null: false
    t.decimal "locked_margin", precision: 36, scale: 18, default: "0.0", null: false
    t.string "margin_type", default: "cross", null: false
    t.string "option_type"
    t.integer "order_kind", default: 0, null: false
    t.datetime "placed_at", null: false
    t.decimal "price", precision: 36, scale: 18
    t.decimal "quantity", precision: 36, scale: 18, null: false
    t.datetime "rejected_at"
    t.text "rejection_reason"
    t.string "security_id"
    t.string "series"
    t.integer "side", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.decimal "strike_price", precision: 36, scale: 18
    t.string "symbol", null: false
    t.decimal "trigger_price", precision: 36, scale: 18
    t.datetime "updated_at", null: false
    t.datetime "expired_at"
    # Architecture alignment: venue identifies the exchange that sourced this
    # order (e.g. binance_usdm, coindcx_futures, or paper for local sims).
    t.string "venue", default: "paper", null: false
    t.index ["account_id", "client_order_id"], name: "index_paper_orders_on_account_and_client_order_id", unique: true
    t.index ["account_id", "placed_at", "id"], name: "index_paper_orders_on_account_placed_id"
    t.index ["account_id"], name: "index_paper_exchange_orders_on_account_id"
    t.index ["instrument_type", "option_type", "strike_price", "expiry_date"], name: "index_paper_orders_instrument"
    t.index ["status"], name: "index_paper_exchange_orders_on_status"
    t.index ["symbol"], name: "index_paper_exchange_orders_on_symbol"
    t.index ["venue", "status"], name: "index_paper_orders_on_venue_and_status"
  end

  create_table "paper_exchange_positions", force: :cascade do |t|
    t.string "account_id", null: false
    t.decimal "avg_price", precision: 36, scale: 18
    t.datetime "created_at", null: false
    t.decimal "current_price", precision: 36, scale: 18
    t.date "expiry_date"
    t.decimal "initial_margin", precision: 36, scale: 18, default: "0.0", null: false
    t.string "instrument_type", default: "EQUITY", null: false
    t.integer "leverage", default: 1, null: false
    t.decimal "liquidation_price", precision: 36, scale: 18
    t.string "margin_type", default: "cross", null: false
    t.string "option_type"
    t.decimal "quantity", precision: 36, scale: 18, default: "0.0", null: false
    t.integer "side", null: false
    t.decimal "strike_price", precision: 36, scale: 18
    t.string "symbol", null: false
    # Architecture alignment: venue identifies the exchange that sourced this
    # position, so a BTCUSDT long on Binance is distinct from one on CoinDCX.
    t.string "venue", default: "paper", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "symbol", "instrument_type", "option_type", "strike_price", "expiry_date"], name: "index_paper_positions_uniqueness", unique: true
    t.index ["account_id", "symbol", "instrument_type"], name: "index_paper_positions_contract_strict", unique: true, where: "((option_type IS NULL) AND (strike_price IS NULL) AND (expiry_date IS NULL))"
    t.index ["venue", "account_id", "symbol"], name: "index_paper_positions_on_venue_account_symbol"
  end

  create_table "paper_exchange_trades", force: :cascade do |t|
    t.jsonb "charges", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "fill_type", default: "full"
    t.bigint "paper_order_id", null: false
    t.bigint "paper_position_id"
    t.decimal "price", precision: 36, scale: 18, null: false
    t.decimal "quantity", precision: 36, scale: 18, null: false
    t.string "side", null: false
    t.decimal "total_charges", precision: 36, scale: 18, default: "0.0", null: false
    t.datetime "traded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["paper_order_id"], name: "index_paper_exchange_trades_on_paper_order_id"
    t.index ["paper_position_id"], name: "index_paper_exchange_trades_on_paper_position_id"
  end

  create_table "risk_events", force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.string "event_type", null: false
    t.string "signal_id"
    t.index ["account_id", "created_at", "id"], name: "index_risk_events_on_account_created_id"
    t.index ["account_id"], name: "index_risk_events_on_account_id"
    t.index ["created_at"], name: "index_risk_events_on_created_at"
    t.index ["event_type"], name: "index_risk_events_on_event_type"
  end

  add_foreign_key "funding_payments", "paper_exchange_positions", column: "paper_position_id"
  add_foreign_key "paper_exchange_trades", "paper_exchange_orders", column: "paper_order_id"
  add_foreign_key "paper_exchange_trades", "paper_exchange_positions", column: "paper_position_id"
  # Prod-hardening (NEW-30): structural integrity from every money table back
  # to accounts(account_id). Previously app-layer only; a stray write for a
  # non-existent account would corrupt the Reconciler's wallet derivation.
  # primary_key: :account_id because accounts uses a string business key, not
  # the bigint id PK — without this Postgres raises DatatypeMismatch.
  add_foreign_key "funding_payments", "accounts", column: "account_id", primary_key: "account_id"
  add_foreign_key "ledger_entries", "accounts", column: "account_id", primary_key: "account_id"
  add_foreign_key "paper_exchange_orders", "accounts", column: "account_id", primary_key: "account_id"
  add_foreign_key "paper_exchange_positions", "accounts", column: "account_id", primary_key: "account_id"
  add_foreign_key "risk_events", "accounts", column: "account_id", primary_key: "account_id"
  add_foreign_key "backtest_bars", "backtest_datasets"
  add_foreign_key "backtest_equity_points", "backtest_runs"
  add_foreign_key "backtest_intents", "backtest_intents", column: "parent_intent_id"
  add_foreign_key "backtest_intents", "backtest_runs"
  add_foreign_key "backtest_runs", "backtest_datasets"
  add_foreign_key "backtest_trades", "backtest_runs"
end
