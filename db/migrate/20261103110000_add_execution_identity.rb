# Execution identity on fill rows (MULTI_MARKET_SPEC §5.2). A fill is idempotent
# per order: the same execution_key cannot be booked twice.
class AddExecutionIdentity < ActiveRecord::Migration[8.1]
  def change
    add_column :paper_exchange_trades, :execution_key, :string
    add_column :paper_exchange_trades, :liquidity_source, :string # top_of_book_model | book_l2 | legacy
    add_column :paper_exchange_trades, :charge_rule_ids, :jsonb, null: false, default: []
    add_index :paper_exchange_trades, %i[paper_order_id execution_key],
      unique: true, where: "execution_key IS NOT NULL",
      name: "index_paper_trades_on_order_execution_key"

    add_reference :paper_exchange_orders, :instrument, foreign_key: true, index: true
  end
end
