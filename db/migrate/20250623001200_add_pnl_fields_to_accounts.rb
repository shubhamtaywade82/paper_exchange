class AddPnlFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    change_table :accounts, bulk: true do |t|
      t.decimal :unrealized_pnl, precision: 18, scale: 4, default: 0.0, null: false
      t.decimal :realized_pnl, precision: 18, scale: 4, default: 0.0, null: false
    end
  end
end
