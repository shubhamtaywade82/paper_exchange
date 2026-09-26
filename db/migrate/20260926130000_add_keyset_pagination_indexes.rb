# frozen_string_literal: true

# Audit N6 (T5.4): the list endpoints (orders, ledger, risk_events) had a
# hard cap and no pagination — history was silently truncated for active
# accounts. They now use keyset (cursor) pagination ordered
# (sort_column DESC, id DESC); these composite indexes back that access
# path per account.
#
# paper_exchange_orders.placed_at also becomes NOT NULL: the keyset
# comparison relies on a total order, and a NULL placed_at would sort
# unpredictably at the page boundary. The model has always set it on
# create (before_validation :set_placed_at); the backfill below covers
# any legacy row written by an even older path.
class AddKeysetPaginationIndexes < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE paper_exchange_orders SET placed_at = created_at WHERE placed_at IS NULL"
    change_column_null :paper_exchange_orders, :placed_at, false

    add_index :paper_exchange_orders, %i[account_id placed_at id],
      name: "index_paper_orders_on_account_placed_id"
    add_index :ledger_entries, %i[account_id occurred_at id],
      name: "index_ledger_entries_on_account_occurred_id"
    add_index :risk_events, %i[account_id created_at id],
      name: "index_risk_events_on_account_created_id"
  end

  def down
    remove_index :paper_exchange_orders, name: "index_paper_orders_on_account_placed_id"
    remove_index :ledger_entries, name: "index_ledger_entries_on_account_occurred_id"
    remove_index :risk_events, name: "index_risk_events_on_account_created_id"
    change_column_null :paper_exchange_orders, :placed_at, true
  end
end
