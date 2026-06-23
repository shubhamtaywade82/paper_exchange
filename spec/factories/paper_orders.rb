FactoryBot.define do
  factory :paper_order do
    account_id { "ACC-TEST" }
    symbol { "NIFTY" }
    side { :buy }
    quantity { 50 }
    kind { :market }
    instrument_type { "OPTIDX" }
    option_type { "CE" }
    strike_price { 26000 }
    expiry_date { Date.today + 7 }
    status { :pending }
    price { nil }
    trigger_price { nil }
    filled_quantity { 0 }
  end
end
