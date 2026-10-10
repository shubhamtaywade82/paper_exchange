# Architecture alignment (target architecture §5): durable position
# protection policies. Stored at order acceptance or position creation so
# that stop-loss, take-profit, trailing stops, and OCO behavior survive
# process restarts — the protection worker reloads these from PostgreSQL
# and continues to monitor them even when the trading bot is offline.
#
# A protection is linked to a PaperPosition. When the position is partially
# closed, the protection's quantity is updated; when the position goes flat,
# the protection is cancelled. The protection worker checks each active
# protection against the latest mark price from QuoteStore and triggers
# LiquidationJob-style force-close orders when the breach condition is met.
class CreatePositionProtections < ActiveRecord::Migration[8.1]
  def change
    create_table :position_protections do |t|
      t.references :paper_position, null: false, foreign_key: { to_table: :paper_exchange_positions }
      t.string :account_id, null: false
      t.string :venue, null: false, default: "paper"
      t.string :instrument_id, null: false
      t.string :protection_type, null: false # stop_loss | take_profit | trailing_stop
      t.decimal :trigger_price, precision: 36, scale: 18
      t.decimal :trailing_distance, precision: 36, scale: 18
      t.decimal :quantity, precision: 36, scale: 18, null: false
      t.string :status, null: false, default: "active" # active | triggered | cancelled | expired
      t.string :oco_group_id # links OCO legs (one-cancels-other)
      t.decimal :high_water_mark, precision: 36, scale: 18
      t.decimal :low_water_mark, precision: 36, scale: 18
      t.datetime :triggered_at
      t.datetime :cancelled_at
      t.timestamps
    end

    add_index :position_protections, %i[account_id status], name: "index_position_protections_on_account_status"
    add_index :position_protections, %i[venue instrument_id status], name: "index_position_protections_on_venue_instrument_status"
    add_index :position_protections, :oco_group_id, where: "oco_group_id IS NOT NULL"
    add_index :position_protections, :paper_position_id
  end
end
