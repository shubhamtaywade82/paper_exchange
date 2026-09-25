class AddClientOrderIdToPaperExchangeOrders < ActiveRecord::Migration[8.1]
  def change
    # Nullable + unique per account: Postgres treats multiple NULLs as
    # distinct, so existing/legacy order flows that don't supply one are
    # unaffected. Scoped to account_id (not global) since two independent
    # bots/accounts may reasonably generate overlapping IDs. Required in
    # practice for agent-driven order submission so a network retry can
    # never double-submit — see Exchange::PaperExchange#submit_order.
    add_column :paper_exchange_orders, :client_order_id, :string
    add_index :paper_exchange_orders, [ :account_id, :client_order_id ], unique: true, name: "index_paper_orders_on_account_and_client_order_id"
  end
end
