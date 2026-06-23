class CreatePaperExchangePositions < ActiveRecord::Migration[8.0]
  def change
    create_table :paper_exchange_positions do |t|
      t.string :account_id, null: false
      t.string :symbol, null: false
      t.string :instrument_type, default: "equity", null: false
      t.string :option_type
      t.decimal :strike_price, precision: 18, scale: 2
      t.date :expiry_date
      t.integer :side, null: false
      t.integer :quantity, default: 0, null: false
      t.decimal :avg_price, precision: 18, scale: 2
      t.decimal :current_price, precision: 18, scale: 2
      t.decimal :unrealized_pnl, precision: 18, scale: 4, default: 0, null: false
      t.decimal :realized_pnl, precision: 18, scale: 4, default: 0, null: false

      t.timestamps
    end
    add_index :paper_exchange_positions,
      [:account_id, :symbol, :instrument_type, :option_type, :strike_price, :expiry_date],
      unique: true,
      name: "index_paper_positions_uniqueness"
  end
end
