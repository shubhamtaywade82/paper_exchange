FactoryBot.define do
  factory :paper_position do
    account_id { "ACC-TEST" }
    symbol { "NIFTY" }
    side { :long }
    quantity { 50 }
    avg_price { 100.0 }
    current_price { 105.0 }
  end
end
