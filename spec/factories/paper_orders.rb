FactoryBot.define do
  factory :paper_order, class: PaperExchange::PaperOrder do
    # FK constraint (migration 20261010120000) requires the account to exist.
    account_id { create(:account).account_id }
    symbol { "NIFTY" }
    side { :buy }
    quantity { 50 }
    order_kind { :market }
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
