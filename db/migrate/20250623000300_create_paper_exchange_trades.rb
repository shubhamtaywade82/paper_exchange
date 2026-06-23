class CreatePaperExchangeTrades < ActiveRecord::Migration[8.0]
  def change
    create_table :paper_exchange_trades do |t|
      t.references :paper_order, null: false, foreign_key: { to_table: :paper_exchange_orders }
      t.references :paper_position, null: true, foreign_key: { to_table: :paper_exchange_positions }
      t.string :side, null: false
      t.integer :quantity, null: false
      t.decimal :price, precision: 18, scale: 2, null: false
      t.jsonb :charges, default: {}, null: false
      t.decimal :total_charges, precision: 18, scale: 4, default: 0, null: false
      t.datetime :traded_at, null: false
      t.string :fill_type, default: "full"

      t.timestamps
    end
    add_index :paper_exchange_trades, :paper_order_id, if_not_exists: true
    add_index :paper_exchange_trades, :paper_position_id, if_not_exists: true
  end
end
