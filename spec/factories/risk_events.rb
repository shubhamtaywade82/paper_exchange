FactoryBot.define do
  factory :risk_event, class: 'RiskEvent' do
    # FK constraint (migration 20261010120000) requires the account to exist.
    account_id { create(:account).account_id }
    event_type { "RISK_EVALUATION_ERROR" }
    details { {} }
  end
end
