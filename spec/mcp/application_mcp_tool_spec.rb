# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationMCPTool do
  before do
    Rails.application.eager_load!
  end

  it "exposes only the reviewed read-only tools" do
    expect(ActionMCP::ToolsRegistry.tools.keys).to contain_exactly(
      "get_account_lease",
      "get_account_summary",
      "get_closed_positions",
      "get_exchange_config",
      "get_ledger_entries",
      "get_mark_prices",
      "get_market_structure",
      "get_open_positions",
      "get_option_chain",
      "get_position_details",
      "get_recent_orders",
      "get_risk_events",
      "get_risk_status",
      "get_system_health"
    )
  end

  it "never references order placement or mutation methods from MCP tool code" do
    code_lines = Rails.root.glob("app/mcp/**/*.rb").flat_map { |f| f.readlines.grep_v(/^\s*#/) }
    sources = code_lines.join
    expect(sources).not_to match(/PaperExchange\.submit_order|cancel_order|create!|update!|delete_all|destroy_all/)
  end

  describe GetAccountSummaryTool do
    let(:account) { create(:account, account_id: "test-account-1", margin: 10_000.0, available_balance: 9_500.0, locked_margin: 500.0) }

    before do
      account
      allow(Projections::PortfolioProjection).to receive(:summary).with("test-account-1").and_return({
        equity: 10_000.0,
        max_equity: 10_000.0,
        drawdown: 0.0,
        realized_pnl: 0.0,
        unrealized_pnl: 0.0,
        positions_count: 0
      })
    end

    it "returns account balance and equity summary" do
      response = described_class.new(account_id: "test-account-1").call
      payload = JSON.parse(response.contents.first.text)
      expect(payload["account_id"]).to eq("test-account-1")
      expect(payload["wallet"]["equity"]).to eq("10000.0")
    end
  end

  describe GetExchangeConfigTool do
    it "returns exchange risk limits and rules without secrets" do
      response = described_class.new.call
      payload = JSON.parse(response.contents.first.text)
      expect(payload["risk_limits"]).to be_present
      expect(payload["trading_rules"]).to be_present
    end
  end

  describe GetPositionDetailsTool do
    it "returns position not found when position does not exist" do
      response = described_class.new(position_id: 999_999).call
      payload = JSON.parse(response.contents.first.text)
      expect(payload["error"]).to eq("position_not_found")
    end
  end

  describe GetRecentOrdersTool do
    it "returns order array for account" do
      response = described_class.new(account_id: "test-account-1").call
      payload = JSON.parse(response.contents.first.text)
      expect(payload["account_id"]).to eq("test-account-1")
      expect(payload["orders"]).to be_an(Array)
    end
  end

  describe GetLedgerEntriesTool do
    it "returns ledger entries array for account" do
      response = described_class.new(account_id: "test-account-1").call
      payload = JSON.parse(response.contents.first.text)
      expect(payload["account_id"]).to eq("test-account-1")
      expect(payload["entries"]).to be_an(Array)
    end
  end

  describe ApplicationGateway do
    def gateway_for(authorization, remote_addr: "10.0.0.5", **headers)
      env = Rack::MockRequest.env_for("/", "HTTP_AUTHORIZATION" => authorization, "REMOTE_ADDR" => remote_addr, **headers)
      described_class.new(ActionDispatch::Request.new(env))
    end

    around do |example|
      original = ENV.fetch("MCP_API_TOKEN", nil)
      ENV["MCP_API_TOKEN"] = "secret-token"
      example.run
    ensure
      ENV["MCP_API_TOKEN"] = original
    end

    it "lets clients on loopback in without a token" do
      expect { gateway_for(nil, remote_addr: "127.0.0.1").call }.not_to raise_error
      expect { gateway_for(nil, remote_addr: "::1").call }.not_to raise_error
    end

    it "does not treat proxied loopback traffic as local" do
      proxied = gateway_for(nil, remote_addr: "127.0.0.1", "HTTP_X_FORWARDED_FOR" => "203.0.113.9")
      expect { proxied.call }.to raise_error(ActionMCP::UnauthorizedError)
    end

    it "accepts the configured bearer token" do
      expect { gateway_for("Bearer secret-token").call }.not_to raise_error
    end

    it "rejects a wrong token" do
      expect { gateway_for("Bearer invalid-token").call }.to raise_error(ActionMCP::UnauthorizedError)
    end

    it "allows tokenless access outside production when no token is configured" do
      ENV["MCP_API_TOKEN"] = nil
      expect { gateway_for(nil).call }.not_to raise_error
    end

    it "fails closed in production when no token is configured" do
      ENV["MCP_API_TOKEN"] = nil
      allow(Rails.env).to receive(:production?).and_return(true)
      expect { gateway_for("Bearer anything").call }.to raise_error(ActionMCP::UnauthorizedError)
    end
  end
end
