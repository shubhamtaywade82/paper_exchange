# frozen_string_literal: true

# ============================================================================
# ActionMCP Standalone Server - Rackup Configuration
# ============================================================================
#
# ActionMCP runs as a STANDALONE Rack application on port 62770.
# Do NOT mount ActionMCP::Engine in your routes.rb.
#
# Start this server with:
#   bin/mcp
#
# Port 62770 = MCPS0 on a phone keypad (MCP Server, instance 0)
# ============================================================================

require_relative "../config/environment"

$stdout.sync = true

Rails.application.eager_load!

Signal.trap("INT") do
  puts "\nReceived interrupt signal. Shutting down gracefully..."
  exit(0)
end

Signal.trap("TERM") do
  puts "\nReceived termination signal. Shutting down gracefully..."
  exit(0)
end

run ActionMCP.server
