require 'rails'
require 'action_controller/railtie'
require 'active_record/railtie'
require 'active_job/railtie'

module PaperExchange
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.autoload_paths << Rails.root.join('app/services')
    config.autoload_paths += Dir[Rails.root.join('app/services/**/')]
  end
end

Bundler.require(*Rails.groups)
