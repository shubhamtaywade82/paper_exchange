# Architecture alignment (target architecture §4): add a `venue` column to
# orders and positions so "BTCUSDT" on Binance is distinct from "BTCUSDT"
# on CoinDCX. Without this, a position opened on Binance could be
# erroneously closed by an order targeting CoinDCX — the symbol alone is
# not a unique contract identifier across venues.
#
# Defaults to "paper" for backward compatibility — existing rows predate the
# venue concept and were created through the local simulator, not a live
# exchange feed. New orders inherit the venue from the market-data source
# that drove the fill, or "paper" when the agent supplies execution_price
# directly (the replay/test override path).
class AddVenueToOrdersAndPositions < ActiveRecord::Migration[8.1]
  def up
    add_column :paper_exchange_orders, :venue, :string, null: false, default: "paper"
    add_column :paper_exchange_positions, :venue, :string, null: false, default: "paper"

    add_index :paper_exchange_orders, %i[venue status], name: "index_paper_orders_on_venue_and_status"
    add_index :paper_exchange_positions, %i[venue account_id symbol], name: "index_paper_positions_on_venue_account_symbol"
  end

  def down
    remove_index :paper_exchange_orders, name: "index_paper_orders_on_venue_and_status"
    remove_index :paper_exchange_positions, name: "index_paper_positions_on_venue_account_symbol"
    remove_column :paper_exchange_orders, :venue
    remove_column :paper_exchange_positions, :venue
  end
end
