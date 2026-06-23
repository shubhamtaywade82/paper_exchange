class CreateOptionSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :option_snapshots do |t|
      t.string :symbol, null: false
      t.string :underlying, null: false
      t.string :option_type, null: false
      t.decimal :strike_price, precision: 18, scale: 2, null: false
      t.date :expiry_date, null: false
      t.decimal :ltp, precision: 18, scale: 2
      t.decimal :iv, precision: 18, scale: 6
      t.decimal :delta, precision: 18, scale: 6
      t.decimal :theta, precision: 18, scale: 6
      t.decimal :gamma, precision: 18, scale: 6
      t.decimal :vega, precision: 18, scale: 6
      t.decimal :rho, precision: 18, scale: 6
      t.integer :oi, default: 0, null: false
      t.integer :volume, default: 0, null: false
      t.decimal :bid, precision: 18, scale: 2
      t.decimal :ask, precision: 18, scale: 2
      t.datetime :snapshot_at, null: false

      t.timestamps
    end
    add_index :option_snapshots, [:underlying, :expiry_date, :strike_price, :option_type], name: "index_option_snapshots_lookup"
    add_index :option_snapshots, :snapshot_at
  end
end
