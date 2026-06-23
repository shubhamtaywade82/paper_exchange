FactoryBot.define do
  factory :account do
    account_id { "ACC-#{SecureRandom.hex(4).upcase}" }
    name { "Test Account" }
    currency { "INR" }
    margin { 500_000.0 }
    current_equity { 500_000.0 }
  end
end
