class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :account_id, null: false
      t.string :name, null: false
      t.string :currency, null: false, default: "INR"
      t.decimal :margin, precision: 18, scale: 4, default: 0.0, null: false
      t.decimal :current_equity, precision: 18, scale: 4, default: 0.0, null: false

      t.timestamps
    end

    add_index :accounts, :account_id, unique: true
  end
end
