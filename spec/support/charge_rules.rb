# Every example starts with exactly the India charge rules that production has
# after `bin/rails charges:install_legacy_rules`. Rows written by specs that run
# outside a transaction (for example, the concurrency spec) can be left behind,
# so this clears the table first, inside the example's own transaction.
RSpec.configure do |config|
  config.before do
    ChargeRule.delete_all
    Charges::LegacyRules.install!
  end
end
