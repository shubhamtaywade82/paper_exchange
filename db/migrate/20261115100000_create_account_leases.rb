# One lease per (venue, account): the single writer allowed to change a live account. A row with no holder is free.
# `fence` rises on every acquisition, so a holder that lost its lease cannot write under a fence it no longer holds.
# Expiry is judged against the database clock (now()), never a client's, so skew between hosts cannot extend a lease.
class CreateAccountLeases < ActiveRecord::Migration[8.1]
  def change
    create_table :account_leases do |t|
      t.string :venue, null: false, default: "paper_exchange"
      t.string :account_id, null: false
      t.string :holder_id
      t.string :holder_label
      t.bigint :fence, null: false, default: 0
      t.datetime :acquired_at
      t.datetime :heartbeat_at
      t.datetime :expires_at
      t.datetime :released_at

      t.timestamps
    end

    add_index :account_leases, %i[venue account_id], unique: true
    add_check_constraint :account_leases, "fence >= 0", name: "account_leases_fence_non_negative"
  end
end
