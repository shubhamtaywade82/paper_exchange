require 'rails'
require 'action_controller/railtie'

module PaperExchange
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.autoload_paths << Rails.root.join('app/services')
  end
end
