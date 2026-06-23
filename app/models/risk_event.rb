class RiskEvent < ApplicationRecord
  self.table_name = "risk_events"

  validates :account_id, presence: true
  validates :event_type, presence: true
end
