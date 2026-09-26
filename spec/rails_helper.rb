# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
# Audit M2: the shared API key every authenticated request must present.
ENV['PAPER_EXCHANGE_API_KEY'] ||= 'test-api-key-123'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default.
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  config.filter_rails_from_backtrace!
  config.filter_gems_from_backtrace('dhanhq', 'coindcx-client')

  config.include ActiveJob::TestHelper, type: :job

  # Audit M2: controller specs must authenticate like real clients — the
  # Api::BaseController before_action would otherwise 401 every request.
  config.before(:each, type: :controller) do
    request.headers["X-API-Key"] = ENV.fetch("PAPER_EXCHANGE_API_KEY")
  end

  # Shoulda Matchers config
  Shoulda::Matchers.configure do |shoulda_config|
    shoulda_config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
end
