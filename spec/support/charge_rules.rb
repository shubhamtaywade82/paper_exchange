# Every example starts with the India charge rules installed, as production has
# them after `bin/rails charges:install_legacy_rules`. The rows are written inside
# the example's transaction, so they roll back with it.
RSpec.configure do |config|
  config.before do
    Charges::LegacyRules.install!
  end
end
