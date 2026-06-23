module PaperExchange
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true

    # Zeitwerk-managed service namespaces (Risk, Strategy, Projections, Ledger, MarketData, Exchange)
    config.autoload_paths << Rails.root.join('app/services')
  end
end

Bundler.require(*Rails.groups)
