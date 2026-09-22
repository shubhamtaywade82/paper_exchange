class AdaptSchemaForCryptoFutures < ActiveRecord::Migration[8.1]
  DECIMAL = { precision: 36, scale: 18 }.freeze

  def up
    # ── Accounts: wallet split (available vs locked margin) ────────────────
    change_column :accounts, :margin, :decimal, **DECIMAL
    change_column :accounts, :current_equity, :decimal, **DECIMAL
    change_column :accounts, :realized_pnl, :decimal, **DECIMAL
    change_column :accounts, :unrealized_pnl, :decimal, **DECIMAL

    add_column :accounts, :available_balance, :decimal, **DECIMAL, default: "0.0", null: false
    add_column :accounts, :locked_margin, :decimal, **DECIMAL, default: "0.0", null: false

    # Backfill: existing accounts have no locked margin yet, so the whole
    # margin balance is available.
    execute "UPDATE accounts SET available_balance = margin, locked_margin = 0"

    # ── Orders: fractional (crypto) quantities + leverage intent ───────────
    change_column :paper_exchange_orders, :quantity, :decimal, **DECIMAL, null: false
    change_column :paper_exchange_orders, :filled_quantity, :decimal, **DECIMAL, default: "0.0", null: false
    change_column :paper_exchange_orders, :price, :decimal, **DECIMAL
    change_column :paper_exchange_orders, :avg_fill_price, :decimal, **DECIMAL
    change_column :paper_exchange_orders, :trigger_price, :decimal, **DECIMAL
    change_column :paper_exchange_orders, :strike_price, :decimal, **DECIMAL

    add_column :paper_exchange_orders, :leverage, :integer, default: 1, null: false
    add_column :paper_exchange_orders, :margin_type, :string, default: "cross", null: false
    add_column :paper_exchange_orders, :locked_margin, :decimal, **DECIMAL, default: "0.0", null: false

    # ── Positions: futures mechanics (leverage, margin type, liquidation) ──
    change_column :paper_exchange_positions, :quantity, :decimal, **DECIMAL, default: "0.0", null: false
    change_column :paper_exchange_positions, :avg_price, :decimal, **DECIMAL
    change_column :paper_exchange_positions, :current_price, :decimal, **DECIMAL
    change_column :paper_exchange_positions, :strike_price, :decimal, **DECIMAL

    add_column :paper_exchange_positions, :leverage, :integer, default: 1, null: false
    add_column :paper_exchange_positions, :margin_type, :string, default: "cross", null: false
    add_column :paper_exchange_positions, :liquidation_price, :decimal, **DECIMAL
    add_column :paper_exchange_positions, :initial_margin, :decimal, **DECIMAL, default: "0.0", null: false

    # ── Trades: fractional fills ────────────────────────────────────────────
    change_column :paper_exchange_trades, :quantity, :decimal, **DECIMAL, null: false
    change_column :paper_exchange_trades, :price, :decimal, **DECIMAL, null: false
    change_column :paper_exchange_trades, :total_charges, :decimal, **DECIMAL, default: "0.0", null: false

    # ── Ledger: high-precision debit/credit ─────────────────────────────────
    change_column :ledger_entries, :debit, :decimal, **DECIMAL, default: "0.0", null: false
    change_column :ledger_entries, :credit, :decimal, **DECIMAL, default: "0.0", null: false
    change_column :ledger_entries, :balance_after, :decimal, **DECIMAL

    # ── Funding payments: append-only perpetual futures funding history ────
    create_table :funding_payments do |t|
      t.string :account_id, null: false
      t.bigint :paper_position_id
      t.string :symbol, null: false
      t.decimal :funding_rate, **DECIMAL, null: false
      t.decimal :position_notional, **DECIMAL, null: false
      t.decimal :amount, **DECIMAL, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :funding_payments, :account_id
    add_index :funding_payments, :paper_position_id
    add_index :funding_payments, [:symbol, :occurred_at]
    add_foreign_key :funding_payments, :paper_exchange_positions, column: :paper_position_id
  end

  def down
    remove_foreign_key :funding_payments, column: :paper_position_id
    drop_table :funding_payments

    change_column :ledger_entries, :balance_after, :decimal, precision: 18, scale: 4
    change_column :ledger_entries, :credit, :decimal, precision: 18, scale: 2, default: "0.0", null: false
    change_column :ledger_entries, :debit, :decimal, precision: 18, scale: 2, default: "0.0", null: false

    change_column :paper_exchange_trades, :total_charges, :decimal, precision: 18, scale: 4, default: "0.0", null: false
    change_column :paper_exchange_trades, :price, :decimal, precision: 18, scale: 2, null: false
    change_column :paper_exchange_trades, :quantity, :integer, null: false

    remove_column :paper_exchange_positions, :initial_margin
    remove_column :paper_exchange_positions, :liquidation_price
    remove_column :paper_exchange_positions, :margin_type
    remove_column :paper_exchange_positions, :leverage
    change_column :paper_exchange_positions, :strike_price, :decimal, precision: 18, scale: 2
    change_column :paper_exchange_positions, :current_price, :decimal, precision: 18, scale: 2
    change_column :paper_exchange_positions, :avg_price, :decimal, precision: 18, scale: 2
    change_column :paper_exchange_positions, :quantity, :integer, default: 0, null: false

    remove_column :paper_exchange_orders, :locked_margin
    remove_column :paper_exchange_orders, :margin_type
    remove_column :paper_exchange_orders, :leverage
    change_column :paper_exchange_orders, :strike_price, :decimal, precision: 18, scale: 2
    change_column :paper_exchange_orders, :trigger_price, :decimal, precision: 18, scale: 2
    change_column :paper_exchange_orders, :avg_fill_price, :decimal, precision: 18, scale: 2
    change_column :paper_exchange_orders, :price, :decimal, precision: 18, scale: 2
    change_column :paper_exchange_orders, :filled_quantity, :integer, default: 0, null: false
    change_column :paper_exchange_orders, :quantity, :integer, null: false

    remove_column :accounts, :locked_margin
    remove_column :accounts, :available_balance
    change_column :accounts, :unrealized_pnl, :decimal, precision: 18, scale: 4, default: "0.0", null: false
    change_column :accounts, :realized_pnl, :decimal, precision: 18, scale: 4, default: "0.0", null: false
    change_column :accounts, :current_equity, :decimal, precision: 18, scale: 4, default: "0.0", null: false
    change_column :accounts, :margin, :decimal, precision: 18, scale: 4, default: "0.0", null: false
  end
end
