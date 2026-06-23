class OptionSnapshot < ApplicationRecord
  self.table_name = "option_snapshots"

  validates :symbol, presence: true
  validates :underlying, presence: true
  validates :option_type, presence: true
  validates :strike_price, presence: true
  validates :expiry_date, presence: true
  validates :oi, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :volume, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
