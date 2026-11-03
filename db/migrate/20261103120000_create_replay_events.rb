# Sequenced market events for tick and L2 replay (MULTI_MARKET_SPEC §5.3).
class CreateReplayEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :replay_events do |t|
      t.references :backtest_dataset, null: false, foreign_key: true
      t.string :symbol, null: false
      t.bigint :sequence, null: false              # exchange sequence or update id, per symbol
      t.string :event_type, null: false
      t.datetime :event_at, null: false            # exchange timestamp, UTC
      t.jsonb :payload, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :replay_events, %i[backtest_dataset_id symbol event_type sequence],
      unique: true, name: "index_replay_events_on_identity"
    add_index :replay_events, %i[backtest_dataset_id event_at sequence],
      name: "index_replay_events_on_dataset_time"
    add_check_constraint :replay_events,
      "event_type IN ('snapshot','depth_delta','trade','mark','funding')",
      name: "replay_events_type_valid"
  end
end
