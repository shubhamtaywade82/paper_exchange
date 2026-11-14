require "rails"
require "action_controller/railtie"
require "active_record/railtie"
require "active_job/railtie"
# #8: the fills stream (FillsChannel). The API-only app does not load ActionCable
# by default. ActionCable mounts itself at /cable.
require "action_cable/engine"

module PaperExchange
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true

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
