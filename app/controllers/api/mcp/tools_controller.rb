# frozen_string_literal: true

module Api
  module MCP
    class ToolsController < BaseController
      # GET /api/mcp/tools
      def index
        tools = bridge.list_tools.map { |t| t.slice("name", "description", "inputSchema") }
        render json: { online: true, url: ::MCP::OllamaBridge::DEFAULT_URL, model: bridge.model, tools: tools }
      rescue *UNREACHABLE_ERRORS, ::MCP::OllamaBridge::Error => e
        render json: { online: false, url: ::MCP::OllamaBridge::DEFAULT_URL, model: bridge.model, tools: [], error: e.message }
      end
    end
  end
end
