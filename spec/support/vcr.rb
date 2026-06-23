# spec/support/vcr.rb
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join('spec', 'cassettes')
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<DHAN_ACCESS_TOKEN>') { ENV['DHAN_ACCESS_TOKEN'] }
  config.filter_sensitive_data('<DHAN_CLIENT_ID>') { ENV['DHAN_CLIENT_ID'] }
  config.filter_sensitive_data('<COINDCX_API_KEY>') { ENV['COINDCX_API_KEY'] }
  config.filter_sensitive_data('<COINDCX_API_SECRET>') { ENV['COINDCX_API_SECRET'] }
  config.filter_sensitive_data('<BINANCE_API_KEY>') { ENV['BINANCE_API_KEY'] }
  config.filter_sensitive_data('<BINANCE_API_SECRET>') { ENV['BINANCE_API_SECRET'] }
end
