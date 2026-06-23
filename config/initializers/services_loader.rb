# Configure Zeitwerk to autoload service namespaces in api_only mode.
if Rails.autoloaders.main.respond_to?(:push_dir)
  Rails.autoloaders.main.push_dir(Rails.root.join("app/services"))
end
