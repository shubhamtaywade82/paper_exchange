# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::MCP::Questions", type: :request do
  let(:headers) { { "X-API-Key" => ENV.fetch("PAPER_EXCHANGE_API_KEY") } }
  let(:mock_bridge) { instance_double(MCP::OllamaBridge, model: "test-model", tools_used: ["get_account_summary"]) }

  before do
    allow(MCP::OllamaBridge).to receive(:new).and_return(mock_bridge)
  end

  describe "GET /api/v1/mcp/tools" do
    it "returns the list of tools available on the MCP server" do
      allow(mock_bridge).to receive(:list_tools).and_return([
        { "name" => "get_account_summary", "description" => "Account summary", "inputSchema" => {} }
      ])

      get "/api/v1/mcp/tools", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["online"]).to be true
      expect(response.parsed_body["tools"].first["name"]).to eq("get_account_summary")
    end
  end

  describe "POST /api/v1/mcp/questions" do
    it "asks the question through the bridge and returns the answer" do
      allow(mock_bridge).to receive(:ask).with("How is the account?").and_return("Account is healthy.")

      post "/api/v1/mcp/questions", params: { question: "How is the account?" }, headers: headers, as: :json
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["answer"]).to eq("Account is healthy.")
      expect(response.parsed_body["tools_used"]).to eq(["get_account_summary"])
    end

    it "rejects blank questions" do
      post "/api/v1/mcp/questions", params: { question: "   " }, headers: headers, as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end
end
