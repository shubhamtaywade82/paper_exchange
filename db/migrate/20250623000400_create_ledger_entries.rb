class CreateLedgerEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_entries do |t|
      t.string :account_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, default: {}, null: false
      t.decimal :debit, precision: 18, scale: 2, default: 0, null: false
      t.decimal :credit, precision: 18, scale: 2, default: 0, null: false
      t.decimal :balance_after, precision: 18, scale: 4
      t.string :reference_id
      t.string :currency, default: "INR", null: false
      t.datetime :occurred_at, null: false
      t.datetime :posted_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
      t.timestamps
    end
    add_index :ledger_entries, :account_id
    add_index :ledger_entries, :event_type
    add_index :ledger_entries, :occurred_at
  end
end
