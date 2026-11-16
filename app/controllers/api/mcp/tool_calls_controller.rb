# frozen_string_literal: true

module Api
  module MCP
    class ToolCallsController < BaseController
      # POST /api/mcp/tools/:tool_id/calls
      def create
        arguments = params.fetch(:arguments, {}).permit!.to_h
        text = bridge.call_tool(params[:tool_id], arguments)
        render json: { name: params[:tool_id], result: parse_json(text) }, status: :created
      rescue *UNREACHABLE_ERRORS, ::MCP::OllamaBridge::Error => e
        render_mcp_error(e)
      end

      private

      def parse_json(text)
        JSON.parse(text)
      rescue JSON::ParserError
        text
      end
    end
  end
end
