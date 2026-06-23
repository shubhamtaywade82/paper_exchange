FactoryBot.define do
  factory :risk_event do
    account_id { "ACC-TEST" }
    event_type { "RISK_EVALUATION_ERROR" }
    details { {} }
  end
end
