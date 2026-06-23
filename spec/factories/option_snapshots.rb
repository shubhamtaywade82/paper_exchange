FactoryBot.define do
  factory :option_snapshot, class: 'OptionSnapshot' do
    underlying { 'NIFTY' }
    symbol { "#{underlying}26JUN#{26000}C" }
    option_type { 'CE' }
    strike_price { 25000 }
    expiry_date { Date.today + 30 }
    oi { 500 }
    volume { 100 }
    snapshot_at { Time.current }
  end
end
