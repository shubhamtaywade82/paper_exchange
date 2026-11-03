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

ActiveRecord::Schema[8.1].define(version: 2026_11_03_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
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
    t.decimal "realized_pnl", precision: 36, scale: 18, default: "0.0", null: false
    t.decimal "unrealized_pnl", precision: 36, scale: 18, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.decimal "max_equity_achieved", precision: 36, scale: 18, default: "0.0", null: false
    t.boolean "simulated", default: false, null: false
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
    t.string "fidelity", default: "ohlc_bar", null: false
    t.index ["account_id"], name: "index_backtest_runs_on_account_id", unique: true
    t.index ["backtest_dataset_id"], name: "index_backtest_runs_on_backtest_dataset_id"
    t.index ["created_at"], name: "index_backtest_runs_on_created_at"
    t.index ["status"], name: "index_backtest_runs_on_status"
    t.check_constraint "fidelity::text = ANY (ARRAY['ohlc_bar'::character varying, 'trade_tick'::character varying, 'l1'::character varying, 'l2'::character varying]::text[])", name: "backtest_runs_fidelity_valid"
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

  create_table "charge_rules", force: :cascade do |t|
    t.bigint "exchange_id"
    t.string "product", null: false
    t.string "side", null: false
    t.string "component", null: false
    t.string "basis", null: false
    t.decimal "rate", precision: 20, scale: 10
    t.decimal "flat_amount", precision: 36, scale: 18
    t.decimal "minimum_amount", precision: 36, scale: 18
    t.decimal "maximum_amount", precision: 36, scale: 18
    t.integer "rounding_scale"
    t.jsonb "base_components"
    t.date "effective_from", null: false
    t.date "effective_until"
    t.string "source_ref", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_id"], name: "index_charge_rules_on_exchange_id"
    t.check_constraint "(rate IS NOT NULL) <> (flat_amount IS NOT NULL) OR basis::text = 'component_sum'::text", name: "charge_rules_one_amount_source"
    t.check_constraint "basis::text = ANY (ARRAY['turnover'::character varying, 'flat'::character varying, 'component_sum'::character varying]::text[])", name: "charge_rules_basis_valid"
    t.check_constraint "side::text = ANY (ARRAY['buy'::character varying, 'sell'::character varying, 'both'::character varying]::text[])", name: "charge_rules_side_valid"
    t.exclusion_constraint "product WITH =, component WITH =, side WITH =, COALESCE(exchange_id, (0)::bigint) WITH =, daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[]'::text) WITH &&", using: :gist, name: "charge_rules_no_overlap"
  end

  create_table "exchanges", force: :cascade do |t|
    t.string "code", null: false
    t.string "time_zone", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_exchanges_on_code", unique: true
    t.check_constraint "time_zone::text <> ''::text", name: "exchanges_time_zone_present"
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

  create_table "instrument_specs", force: :cascade do |t|
    t.bigint "instrument_id", null: false
    t.datetime "valid_from", null: false
    t.datetime "valid_until"
    t.decimal "lot_size", precision: 36, scale: 18, null: false
    t.decimal "tick_size", precision: 36, scale: 18, null: false
    t.decimal "freeze_quantity", precision: 36, scale: 18
    t.string "settlement_type", null: false
    t.string "source", null: false
    t.string "source_checksum", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["instrument_id"], name: "index_instrument_specs_on_instrument_id"
    t.check_constraint "lot_size > 0::numeric AND tick_size > 0::numeric", name: "instrument_specs_positive_units"
    t.check_constraint "settlement_type::text = ANY (ARRAY['cash'::character varying, 'physical'::character varying, 'none'::character varying]::text[])", name: "instrument_specs_settlement_valid"
    t.check_constraint "valid_until IS NULL OR valid_until > valid_from", name: "instrument_specs_valid_window"
    t.exclusion_constraint "instrument_id WITH =, tsrange(valid_from, COALESCE(valid_until, 'infinity'::timestamp without time zone), '[)'::text) WITH &&", using: :gist, name: "instrument_specs_no_overlap"
  end

  create_table "instruments", force: :cascade do |t|
    t.bigint "exchange_id", null: false
    t.string "exchange_segment", null: false
    t.string "security_id", null: false
    t.string "symbol", null: false
    t.string "instrument_type", null: false
    t.bigint "underlying_id"
    t.string "option_type"
    t.decimal "strike_price", precision: 36, scale: 18
    t.date "expiry_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_id", "exchange_segment", "security_id"], name: "index_instruments_on_identity", unique: true
    t.index ["exchange_id"], name: "index_instruments_on_exchange_id"
    t.index ["symbol", "instrument_type", "expiry_date"], name: "idx_on_symbol_instrument_type_expiry_date_a6e8f1e6b2"
    t.index ["underlying_id"], name: "index_instruments_on_underlying_id"
    t.check_constraint "(instrument_type::text <> ALL (ARRAY['FUTIDX'::character varying, 'FUTSTK'::character varying, 'FUTCOM'::character varying, 'FUTCUR'::character varying, 'OPTIDX'::character varying, 'OPTSTK'::character varying, 'OPTFUT'::character varying, 'OPTCUR'::character varying, 'CRYPTO_OPTION'::character varying]::text[])) OR expiry_date IS NOT NULL", name: "instruments_expiry_required"
    t.check_constraint "(instrument_type::text = ANY (ARRAY['OPTIDX'::character varying, 'OPTSTK'::character varying, 'OPTFUT'::character varying, 'OPTCUR'::character varying, 'CRYPTO_OPTION'::character varying]::text[])) = (option_type IS NOT NULL)", name: "instruments_option_fields_consistent"
    t.check_constraint "option_type IS NULL OR (option_type::text = ANY (ARRAY['CE'::character varying, 'PE'::character varying]::text[]))", name: "instruments_option_type_valid"
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

  create_table "market_rules", force: :cascade do |t|
    t.bigint "exchange_id", null: false
    t.string "product", null: false
    t.string "rule_key", null: false
    t.jsonb "value", null: false
    t.date "effective_from", null: false
    t.date "effective_until"
    t.string "source_ref", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_id"], name: "index_market_rules_on_exchange_id"
    t.exclusion_constraint "exchange_id WITH =, product WITH =, rule_key WITH =, daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[]'::text) WITH &&", using: :gist, name: "market_rules_no_overlap"
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
    t.string "venue", default: "paper", null: false
    t.bigint "instrument_id"
    t.index ["account_id", "client_order_id"], name: "index_paper_orders_on_account_and_client_order_id", unique: true
    t.index ["account_id", "placed_at", "id"], name: "index_paper_orders_on_account_placed_id"
    t.index ["account_id"], name: "index_paper_exchange_orders_on_account_id"
    t.index ["instrument_id"], name: "index_paper_exchange_orders_on_instrument_id"
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
    t.datetime "updated_at", null: false
    t.string "venue", default: "paper", null: false
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
    t.string "execution_key"
    t.string "liquidity_source"
    t.jsonb "charge_rule_ids", default: [], null: false
    t.index ["paper_order_id", "execution_key"], name: "index_paper_trades_on_order_execution_key", unique: true, where: "(execution_key IS NOT NULL)"
    t.index ["paper_order_id"], name: "index_paper_exchange_trades_on_paper_order_id"
    t.index ["paper_position_id"], name: "index_paper_exchange_trades_on_paper_position_id"
  end

  create_table "position_protections", force: :cascade do |t|
    t.bigint "paper_position_id", null: false
    t.string "account_id", null: false
    t.string "venue", default: "paper", null: false
    t.string "instrument_id", null: false
    t.string "protection_type", null: false
    t.decimal "trigger_price", precision: 36, scale: 18
    t.decimal "trailing_distance", precision: 36, scale: 18
    t.decimal "quantity", precision: 36, scale: 18, null: false
    t.string "status", default: "active", null: false
    t.string "oco_group_id"
    t.decimal "high_water_mark", precision: 36, scale: 18
    t.decimal "low_water_mark", precision: 36, scale: 18
    t.datetime "triggered_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "trigger_source", default: "mark", null: false
    t.index ["account_id", "status"], name: "index_position_protections_on_account_status"
    t.index ["oco_group_id"], name: "index_position_protections_on_oco_group_id", where: "(oco_group_id IS NOT NULL)"
    t.index ["paper_position_id"], name: "index_position_protections_on_paper_position_id"
    t.index ["venue", "instrument_id", "status"], name: "index_position_protections_on_venue_instrument_status"
    t.check_constraint "trigger_source::text = ANY (ARRAY['last_trade'::character varying, 'bid_ask'::character varying, 'mark'::character varying, 'index'::character varying]::text[])", name: "position_protections_trigger_source_valid"
  end

  create_table "replay_events", force: :cascade do |t|
    t.bigint "backtest_dataset_id", null: false
    t.string "symbol", null: false
    t.bigint "sequence", null: false
    t.string "event_type", null: false
    t.datetime "event_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["backtest_dataset_id", "event_at", "sequence"], name: "index_replay_events_on_dataset_time"
    t.index ["backtest_dataset_id", "symbol", "event_type", "sequence"], name: "index_replay_events_on_identity", unique: true
    t.index ["backtest_dataset_id"], name: "index_replay_events_on_backtest_dataset_id"
    t.check_constraint "event_type::text = ANY (ARRAY['snapshot'::character varying, 'depth_delta'::character varying, 'trade'::character varying, 'mark'::character varying, 'funding'::character varying]::text[])", name: "replay_events_type_valid"
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

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "trading_calendar_days", force: :cascade do |t|
    t.bigint "exchange_id", null: false
    t.string "segment", null: false
    t.date "trade_date", null: false
    t.string "status", null: false
    t.datetime "session_open_at"
    t.datetime "session_close_at"
    t.string "source_ref", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_id", "segment", "trade_date"], name: "index_calendar_days_on_session", unique: true
    t.index ["exchange_id"], name: "index_trading_calendar_days_on_exchange_id"
    t.check_constraint "status::text = 'closed'::text OR session_open_at IS NOT NULL AND session_close_at > session_open_at", name: "trading_calendar_days_session_window"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'closed'::character varying, 'special'::character varying]::text[])", name: "trading_calendar_days_status_valid"
  end

  add_foreign_key "backtest_bars", "backtest_datasets"
  add_foreign_key "backtest_equity_points", "backtest_runs"
  add_foreign_key "backtest_intents", "backtest_intents", column: "parent_intent_id"
  add_foreign_key "backtest_intents", "backtest_runs"
  add_foreign_key "backtest_runs", "backtest_datasets"
  add_foreign_key "backtest_trades", "backtest_runs"
  add_foreign_key "charge_rules", "exchanges"
  add_foreign_key "funding_payments", "accounts", primary_key: "account_id"
  add_foreign_key "funding_payments", "paper_exchange_positions", column: "paper_position_id"
  add_foreign_key "instrument_specs", "instruments"
  add_foreign_key "instruments", "exchanges"
  add_foreign_key "instruments", "instruments", column: "underlying_id"
  add_foreign_key "ledger_entries", "accounts", primary_key: "account_id"
  add_foreign_key "market_rules", "exchanges"
  add_foreign_key "paper_exchange_orders", "accounts", primary_key: "account_id"
  add_foreign_key "paper_exchange_orders", "instruments"
  add_foreign_key "paper_exchange_positions", "accounts", primary_key: "account_id"
  add_foreign_key "paper_exchange_trades", "paper_exchange_orders", column: "paper_order_id"
  add_foreign_key "paper_exchange_trades", "paper_exchange_positions", column: "paper_position_id"
  add_foreign_key "position_protections", "paper_exchange_positions", column: "paper_position_id"
  add_foreign_key "replay_events", "backtest_datasets"
  add_foreign_key "risk_events", "accounts", primary_key: "account_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "trading_calendar_days", "exchanges"
end
