# frozen_string_literal: true

namespace :mcp do
  desc "Ask a local Ollama model a question answered via the ActionMCP tools (server runs via bin/mcp)"
  task :ask, [:question] => :environment do |_task, args|
    question = args[:question].presence || abort('usage: bin/rails "mcp:ask[How is test-account-1 performing?]"')
    bridge = MCP::OllamaBridge.new(
      token: ENV.fetch("MCP_API_TOKEN", nil),
      url: ENV.fetch("MCP_URL", MCP::OllamaBridge::DEFAULT_URL),
      model: ENV.fetch("MCP_OLLAMA_MODEL", MCP::OllamaBridge::DEFAULT_MODEL)
    )
    puts bridge.ask(question)
  end
end
