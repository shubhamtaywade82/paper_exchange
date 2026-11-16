# frozen_string_literal: true

module Api
  module MCP
    class BaseController < Api::BaseController
      skip_before_action :require_account_for_writes
      skip_around_action :fence_live_writes

      UNREACHABLE_ERRORS = [Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Net::OpenTimeout, Net::ReadTimeout].freeze

      private

      def bridge
        @bridge ||= ::MCP::OllamaBridge.new(
          token: ENV.fetch("MCP_API_TOKEN", nil),
          url: ENV.fetch("MCP_URL", ::MCP::OllamaBridge::DEFAULT_URL),
          model: ENV.fetch("MCP_OLLAMA_MODEL", ::MCP::OllamaBridge::DEFAULT_MODEL)
        )
      end

      def render_mcp_error(error)
        render json: { error: error.message }, status: :bad_gateway
      end
    end
  end
end
