# Gemfile loads only debug/prelude, which never opens a remote socket. Open it for
# debug-mcp, but only in the server process: `docker compose exec` commands
# (migrations, ask-rails-harness-mcp) boot Rails too and would fight for the port.
if Rails.env.development? && ENV["RUBY_DEBUG_OPEN"] == "true" && defined?(Rails::Server)
  require "debug/open_nonstop"
end
