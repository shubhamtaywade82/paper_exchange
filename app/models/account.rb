class Account < ApplicationRecord
  self.table_name = "accounts"

  validates :account_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :currency, presence: true, inclusion: { in: %w[INR USD] }
  validates :margin, numericality: { greater_than_or_equal_to: 0 }
  validates :current_equity, numericality: { greater_than_or_equal_to: 0 }
end
