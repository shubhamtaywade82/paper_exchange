FactoryBot.define do
  factory :ledger_entry, class: 'LedgerEntry' do
    account_id { "ACC-TEST" }
    event_type { "trade" }
    debit { 0.0 }
    credit { 5000.0 }
    occurred_at { Time.current }
  end
end
