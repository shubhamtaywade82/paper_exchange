FactoryBot.define do
  factory :account, class: 'Account' do
    account_id { "ACC-#{SecureRandom.hex(4).upcase}" }
    name { "Test Account" }
    currency { "INR" }
    margin { 500_000.0 }
    current_equity { margin }
    available_balance { margin }
    locked_margin { 0.0 }
  end
end
