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

ActiveRecord::Schema[8.1].define(version: 2026_06_23_155819) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "INR", null: false
    t.decimal "current_equity", precision: 18, scale: 4, default: "0.0", null: false
    t.decimal "margin", precision: 18, scale: 4, default: "0.0", null: false
    t.string "name", null: false
    t.decimal "realized_pnl", precision: 18, scale: 4, default: "0.0", null: false
    t.decimal "unrealized_pnl", precision: 18, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_accounts_on_account_id", unique: true
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.string "account_id", null: false
    t.decimal "balance_after", precision: 18, scale: 4
    t.datetime "created_at", null: false
    t.decimal "credit", precision: 18, scale: 2, default: "0.0", null: false
    t.string "currency", default: "INR", null: false
    t.decimal "debit", precision: 18, scale: 2, default: "0.0", null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "posted_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "reference_id"
    t.datetime "updated_at", null: false
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
    t.decimal "avg_fill_price", precision: 18, scale: 2
    t.string "broker_order_id"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.string "exchange_segment"
    t.date "expiry_date"
    t.datetime "filled_at"
    t.integer "filled_quantity", default: 0, null: false
    t.string "instrument_type", default: "EQUITY", null: false
    t.string "option_type"
    t.integer "order_kind", default: 0, null: false
    t.datetime "placed_at"
    t.decimal "price", precision: 18, scale: 2
    t.integer "quantity", null: false
    t.datetime "rejected_at"
    t.text "rejection_reason"
    t.string "security_id"
    t.string "series"
    t.integer "side", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.decimal "strike_price", precision: 18, scale: 2
    t.string "symbol", null: false
    t.decimal "trigger_price", precision: 18, scale: 2
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_paper_exchange_orders_on_account_id"
    t.index ["instrument_type", "option_type", "strike_price", "expiry_date"], name: "index_paper_orders_instrument"
    t.index ["status"], name: "index_paper_exchange_orders_on_status"
    t.index ["symbol"], name: "index_paper_exchange_orders_on_symbol"
  end

  create_table "paper_exchange_positions", force: :cascade do |t|
    t.string "account_id", null: false
    t.decimal "avg_price", precision: 18, scale: 2
    t.datetime "created_at", null: false
    t.decimal "current_price", precision: 18, scale: 2
    t.date "expiry_date"
    t.string "instrument_type", default: "equity", null: false
    t.string "option_type"
    t.integer "quantity", default: 0, null: false
    t.integer "side", null: false
    t.decimal "strike_price", precision: 18, scale: 2
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "symbol", "instrument_type", "option_type", "strike_price", "expiry_date"], name: "index_paper_positions_uniqueness", unique: true
  end

  create_table "paper_exchange_trades", force: :cascade do |t|
    t.jsonb "charges", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "fill_type", default: "full"
    t.bigint "paper_order_id", null: false
    t.bigint "paper_position_id"
    t.decimal "price", precision: 18, scale: 2, null: false
    t.integer "quantity", null: false
    t.string "side", null: false
    t.decimal "total_charges", precision: 18, scale: 4, default: "0.0", null: false
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
    t.index ["account_id"], name: "index_risk_events_on_account_id"
    t.index ["created_at"], name: "index_risk_events_on_created_at"
    t.index ["event_type"], name: "index_risk_events_on_event_type"
  end

  add_foreign_key "paper_exchange_trades", "paper_exchange_orders", column: "paper_order_id"
  add_foreign_key "paper_exchange_trades", "paper_exchange_positions", column: "paper_position_id"
end
