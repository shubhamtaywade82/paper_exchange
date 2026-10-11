FactoryBot.define do
  factory :ledger_entry, class: 'LedgerEntry' do
    # FK constraint (migration 20261010120000) requires the account to exist.
    # Use an association so FactoryBot creates the account automatically.
    account_id { create(:account).account_id }
    event_type { "TRADE" }
    debit { 0.0 }
    credit { 5000.0 }
    occurred_at { Time.current }
  end
end
