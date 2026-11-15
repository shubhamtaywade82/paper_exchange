# The lease row for one (venue, account). Only AccountLeases changes it; everything else reads it.
class AccountLease < ApplicationRecord
  self.table_name = "account_leases"

  validates :venue, :account_id, presence: true
  validates :fence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
