FactoryBot.define do
  factory :paper_trade, class: 'PaperExchange::PaperTrade' do
    association :paper_order, factory: :paper_order
    association :paper_position, factory: :paper_position
    side { "buy" }
    quantity { 50 }
    price { 100.0 }
    traded_at { Time.current }
  end
end
