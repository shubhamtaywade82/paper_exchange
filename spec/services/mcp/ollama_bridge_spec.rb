# frozen_string_literal: true

require "rails_helper"

RSpec.describe MCP::OllamaBridge do
  subject(:bridge) { described_class.new(url: "http://127.0.0.1:62770/") }

  before do
    # Mock initialize handshake
    stub_request(:post, "http://127.0.0.1:62770/")
      .with(body: hash_including("method" => "initialize"))
      .to_return(status: 200, headers: { "Mcp-Session-Id" => "sess-123" }, body: { result: {} }.to_json)

    stub_request(:post, "http://127.0.0.1:62770/")
      .with(body: hash_including("method" => "notifications/initialized"))
      .to_return(status: 200, body: "")
  end

  it "lists tools from the MCP server" do
    stub_request(:post, "http://127.0.0.1:62770/")
      .with(body: hash_including("method" => "tools/list"))
      .to_return(status: 200, body: { result: { tools: [{ "name" => "get_account_summary" }] } }.to_json)

    expect(bridge.list_tools).to eq([{ "name" => "get_account_summary" }])
  end

  it "calls a tool on the MCP server and returns the text content" do
    stub_request(:post, "http://127.0.0.1:62770/")
      .with(body: hash_including("method" => "tools/call", "params" => hash_including("name" => "get_account_summary")))
      .to_return(status: 200, body: { result: { content: [{ "type" => "text", "text" => '{"equity":"10000.0"}' }] } }.to_json)

    expect(bridge.call_tool("get_account_summary")).to eq('{"equity":"10000.0"}')
  end
end
