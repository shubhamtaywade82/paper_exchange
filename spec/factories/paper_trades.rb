FactoryBot.define do
  factory :paper_trade do
    association :paper_order, factory: :paper_order
    association :paper_position, factory: :paper_position
    account_id { "ACC-TEST" }
    symbol { "NIFTY" }
    side { :buy }
    quantity { 50 }
    trade_price { 100.0 }
    trade_type { "regular" }
  end
end
