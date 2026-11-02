# Step-wise replay for bot-driven backtests.
#
#   backtest_intents       every order request a run makes: queued (decided at a
#                          bar, executed at the next open), submitted (linked to
#                          the PaperOrder it created) or rejected. Protective
#                          legs are intents too, so a fill can be traced to the
#                          decision and reason that produced it.
#   backtest_equity_points one row per processed bar (replaces the equity JSON).
#   backtest_runs          mode (engine | external), manifest (what was tested),
#                          benchmarks (thresholds), verdict (pass/fail + checks),
#                          replay_at (the last processed bar).
class CreateReplayApi < ActiveRecord::Migration[8.1]
  MONEY = { precision: 36, scale: 18 }.freeze

  def change
    create_table :backtest_intents do |t|
      t.references :backtest_run, null: false, foreign_key: true
      t.references :parent_intent, foreign_key: { to_table: :backtest_intents }
      t.string :source, null: false
      t.string :role, null: false
      t.string :status, null: false, default: "queued"
      t.string :action, null: false
      t.string :side
      t.string :order_kind
      t.boolean :reduce_only, null: false, default: false
      t.decimal :quantity, **MONEY
      t.decimal :price, **MONEY
      t.decimal :trigger_price, **MONEY
      t.decimal :stop_loss, **MONEY
      t.decimal :take_profit, **MONEY
      t.integer :leverage, null: false, default: 1
      t.string :reason
      t.string :client_order_id
      t.bigint :paper_order_id
      t.datetime :queued_at
      t.datetime :submitted_at
      t.text :rejection_reason
      t.text :note
      t.timestamps
    end
    add_index :backtest_intents, %i[backtest_run_id client_order_id], unique: true,
      where: "client_order_id IS NOT NULL", name: "index_backtest_intents_on_run_and_client_order_id"
    add_index :backtest_intents, :paper_order_id, unique: true, where: "paper_order_id IS NOT NULL"
    add_index :backtest_intents, %i[backtest_run_id status]

    create_table :backtest_equity_points do |t|
      t.references :backtest_run, null: false, foreign_key: true
      t.datetime :bar_at, null: false
      t.decimal :equity, null: false, **MONEY
      t.boolean :in_market, null: false, default: false
      t.datetime :created_at, null: false
    end
    add_index :backtest_equity_points, %i[backtest_run_id bar_at], unique: true

    change_table :backtest_runs do |t|
      t.string :mode, null: false, default: "engine"
      t.jsonb :manifest, null: false, default: {}
      t.jsonb :benchmarks, null: false, default: {}
      t.jsonb :verdict, null: false, default: {}
      t.datetime :replay_at
      t.remove :equity_curve, type: :jsonb, null: false, default: []
    end
  end
end
