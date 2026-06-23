require 'rails'
require 'action_controller/railtie'
require 'active_record/railtie'
require 'active_job/railtie'

module PaperExchange
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true

    # Zeitwerk-managed service namespaces (Risk, Strategy, Projections, Ledger, MarketData, Exchange)
    config.autoload_paths << Rails.root.join('app/services')

    # Acronyms for Zeitwerk camelization
    config.after_initialize do
      Rails.autoloaders.main.inflector.inflect(
        dcx: "DCX",
        usdm: "USDM"
      )
    end
  end
end

Bundler.require(*Rails.groups)
