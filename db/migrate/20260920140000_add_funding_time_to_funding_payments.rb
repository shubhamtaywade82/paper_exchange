# Idempotency for funding events.
#
# Before this migration, POST /api/funding_events was non-idempotent: if the
# trading agent's HTTP request failed transiently (timeout, 5xx, network
# blip) and it retried, the broker would charge funding twice against every
# open leveraged position on that symbol — silent money leak.
#
# Fix: agent supplies a `funding_time` (Binance's funding settlement
# timestamp, or any monotonic ID the agent dedupes on its side). We add a
# unique index on (paper_position_id, funding_time) and use find_or_create_by!
# in FundingJob. A retry hits the existing record and skips the ledger post.
class AddFundingTimeToFundingPayments < ActiveRecord::Migration[8.1]
  def up
    add_column :funding_payments, :funding_time, :datetime
    add_index :funding_payments, [:paper_position_id, :funding_time],
              unique: true,
              name: "index_funding_payments_dedup",
              where: "funding_time IS NOT NULL"
  end

  def down
    remove_index :funding_payments, name: "index_funding_payments_dedup"
    remove_column :funding_payments, :funding_time
  end
end
