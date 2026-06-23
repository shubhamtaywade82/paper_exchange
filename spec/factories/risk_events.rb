FactoryBot.define do
  factory :risk_event, class: 'RiskEvent' do
    account_id { "ACC-TEST" }
    event_type { "RISK_EVALUATION_ERROR" }
    details { {} }
  end
end
