class CreateMarketStructureSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :market_structure_snapshots do |t|
      t.string :symbol, null: false
      t.string :timeframe, null: false, default: "5m"
      t.string :trend
      t.boolean :last_bos, default: false, null: false
      t.boolean :last_choch, default: false, null: false
      t.integer :bullish_fvg_count, default: 0, null: false
      t.integer :bearish_fvg_count, default: 0, null: false
      t.string :liquidity_sweep
      t.string :order_block
      t.string :premium_discount
      t.datetime :as_of, null: false

      t.timestamps
    end
    add_index :market_structure_snapshots, [:symbol, :timeframe, :as_of], name: "index_mss_lookup"
  end
end
