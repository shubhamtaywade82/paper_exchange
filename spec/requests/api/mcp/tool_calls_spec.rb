# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::MCP::ToolCalls", type: :request do
  let(:headers) { { "X-API-Key" => ENV.fetch("PAPER_EXCHANGE_API_KEY") } }
  let(:mock_bridge) { instance_double(MCP::OllamaBridge, model: "test-model", tools_used: []) }

  before do
    allow(MCP::OllamaBridge).to receive(:new).and_return(mock_bridge)
  end

  describe "POST /api/v1/mcp/tools/:tool_id/calls" do
    it "forwards only the arguments a tool declares" do
      allow(mock_bridge).to receive(:call_tool).and_return('{"ok":true}')

      post "/api/v1/mcp/tools/get_risk_status/calls",
        params: { arguments: { account_id: "acc-1", limit: 5, admin: "true", nested: { a: 1 } } },
        headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(mock_bridge).to have_received(:call_tool).with("get_risk_status", { "account_id" => "acc-1", "limit" => 5 })
      expect(response.parsed_body).to eq("name" => "get_risk_status", "result" => { "ok" => true })
    end

    it "calls the tool with no arguments when none are sent" do
      allow(mock_bridge).to receive(:call_tool).and_return("plain text")

      post "/api/v1/mcp/tools/get_system_health/calls", headers: headers, as: :json

      expect(mock_bridge).to have_received(:call_tool).with("get_system_health", {})
      expect(response.parsed_body).to eq("name" => "get_system_health", "result" => "plain text")
    end
  end
end
