class CreatePaperExchangeOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :paper_exchange_orders do |t|
      t.string :account_id, null: false
      t.string :symbol, null: false
      t.string :instrument_type, default: "equity", null: false
      t.string :option_type
      t.decimal :strike_price, precision: 18, scale: 2
      t.date :expiry_date
      t.integer :side, null: false, default: 0
      t.integer :order_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :quantity, null: false
      t.decimal :price, precision: 18, scale: 2
      t.decimal :trigger_price, precision: 18, scale: 2
      t.integer :filled_quantity, default: 0, null: false
      t.decimal :avg_fill_price, precision: 18, scale: 2
      t.string :broker_order_id
      t.datetime :placed_at
      t.datetime :filled_at
      t.datetime :cancelled_at
      t.datetime :rejected_at
      t.text :rejection_reason

      t.timestamps
    end
    add_index :paper_exchange_orders, :account_id
    add_index :paper_exchange_orders, :symbol
    add_index :paper_exchange_orders, :status
  end
end
