class CreateRiskEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :risk_events do |t|
      t.string :account_id, null: false
      t.string :signal_id
      t.string :event_type, null: false
      t.jsonb :details, default: {}, null: false
      t.datetime :created_at, null: false
    end
    add_index :risk_events, :account_id
    add_index :risk_events, :event_type
    add_index :risk_events, :created_at
  end
end
