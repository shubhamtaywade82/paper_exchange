# #19: per-strategy attribution. An order carries the metadata derived from its
# `context` (currently `strategy_key`), and a position records the strategy that
# opened it. Both columns are jsonb with an empty-object default, so existing rows
# are valid and simply carry no attribution.
class AddMetadataToOrdersAndPositions < ActiveRecord::Migration[8.1]
  def change
    add_column :paper_exchange_orders, :metadata, :jsonb, null: false, default: {}
    add_column :paper_exchange_positions, :metadata, :jsonb, null: false, default: {}
  end
end
