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

  describe GetRiskStatusTool do
    around do |example|
      keys = %w[PAPER_EXCHANGE_MAX_POSITIONS PAPER_EXCHANGE_MAX_DRAWDOWN]
      saved = keys.to_h { |key| [ key, ENV.fetch(key, nil) ] }
      keys.each { |key| ENV.delete(key) }
      example.run
      saved.each do |key, value|
        if value.nil?
          ENV.delete(key)
        else
          ENV[key] = value
        end
      end
    end

    before do
      create(:account, account_id: "test-account-1")
      allow(Projections::PortfolioProjection).to receive(:summary).with("test-account-1").and_return({
        drawdown: 2.5, positions_count: 3
      })
    end

    it "reports drawdown and position limits against the defaults, and no lease" do
      payload = JSON.parse(described_class.new.call.contents.first.text)
      expect(payload["account_id"]).to eq("test-account-1")
      expect(payload["risk"]).to include(
        "drawdown_pct" => 2.5, "max_drawdown_limit_pct" => 20.0, "drawdown_breached" => false,
        "positions_count" => 3, "max_positions_limit" => 10, "position_limit_reached" => false
      )
      expect(payload["lease"]).to eq("held" => false, "holder_id" => nil, "fence" => nil, "expires_at" => nil)
    end

    it "flags a breached drawdown and a reached position limit, and reports a live lease" do
      allow(Projections::PortfolioProjection).to receive(:summary).with("test-account-1").and_return({
        drawdown: 25.0, positions_count: 10
      })
      AccountLeases.acquire!(account_id: "test-account-1", holder_id: "agent-a", label: "Agent A", ttl_seconds: 60)

      payload = JSON.parse(described_class.new(account_id: "test-account-1").call.contents.first.text)
      expect(payload["risk"]).to include("drawdown_breached" => true, "position_limit_reached" => true)
      expect(payload["lease"]).to include("held" => true, "holder_id" => "agent-a", "fence" => 1)
      expect(payload["lease"]["expires_at"]).to be_present
    end

    it "does not report an expired lease as held" do
      AccountLeases.acquire!(account_id: "test-account-1", holder_id: "agent-a", label: "Agent A", ttl_seconds: 60)
      AccountLease.where(venue: AccountLeases::VENUE, account_id: "test-account-1")
        .update_all("expires_at = now() - interval '1 second'")

      payload = JSON.parse(described_class.new(account_id: "test-account-1").call.contents.first.text)
      expect(payload["lease"]).to include("held" => false, "holder_id" => nil)
    end

    it "reports an unknown account rather than inventing one" do
      payload = JSON.parse(described_class.new(account_id: "missing").call.contents.first.text)
      expect(payload).to eq("error" => "account_not_found", "account_id" => "missing")
    end
  end

  describe GetSystemHealthTool do
    around do |example|
      keys = %w[PAPER_EXCHANGE_ENABLE_BINANCE PAPER_EXCHANGE_ENABLE_COINDCX]
      saved = keys.to_h { |key| [ key, ENV.fetch(key, nil) ] }
      ENV["PAPER_EXCHANGE_ENABLE_BINANCE"] = "true"
      ENV.delete("PAPER_EXCHANGE_ENABLE_COINDCX")
      example.run
      saved.each do |key, value|
        if value.nil?
          ENV.delete(key)
        else
          ENV[key] = value
        end
      end
    end

    before do
      allow(MarketData::MarkPriceStore).to receive(:redis_healthy?).and_return(true)
    end

    it "reports ok when postgres and redis answer, with the provider flags" do
      payload = JSON.parse(described_class.new.call.contents.first.text)
      expect(payload).to include(
        "status" => "ok", "checks" => { "postgres" => true, "redis" => true, "solid_queue" => true },
        "environment" => "test", "providers" => { "binance_enabled" => true, "coindcx_enabled" => false }
      )
    end

    it "reports degraded when redis is down" do
      allow(MarketData::MarkPriceStore).to receive(:redis_healthy?).and_return(false)
      payload = JSON.parse(described_class.new.call.contents.first.text)
      expect(payload["status"]).to eq("degraded")
      expect(payload["checks"]).to include("redis" => false, "postgres" => true)
    end

    it "treats a redis error as unhealthy rather than raising" do
      allow(MarketData::MarkPriceStore).to receive(:redis_healthy?).and_raise(StandardError, "connection refused")
      payload = JSON.parse(described_class.new.call.contents.first.text)
      expect(payload["checks"]).to include("redis" => false)
    end

    it "treats a postgres error as unhealthy rather than raising" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError, "no database")
      payload = JSON.parse(described_class.new.call.contents.first.text)
      expect(payload["status"]).to eq("degraded")
      expect(payload["checks"]).to include("postgres" => false)
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
