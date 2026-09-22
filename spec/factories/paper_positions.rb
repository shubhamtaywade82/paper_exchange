FactoryBot.define do
  factory :paper_position, class: 'PaperExchange::PaperPosition' do
    account_id { "ACC-TEST" }
    symbol { "NIFTY" }
    side { :long }
    quantity { 50 }
    avg_price { 100.0 }
    current_price { 105.0 }
    # Matches PaperOrder's own default/whitelist casing (uppercase) so a
    # factory-built position is found by the same contract-scoped lookup
    # Exchange::PositionManager.apply! uses in the real order flow.
    instrument_type { "EQUITY" }
  end
end
