namespace :charges do
  desc "Install the legacy India charge rules as effective-dated rows (idempotent)"
  task install_legacy_rules: :environment do
    Charges::LegacyRules.install!
    puts "charge_rules: #{ChargeRule.count} rows (legacy rules unverified; see MULTI_MARKET_SPEC §14)"
  end
end
