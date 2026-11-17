# frozen_string_literal: true

require "rails_helper"

# Behaviour of the read-only MCP tools beyond the shape checks in application_mcp_tool_spec.rb.
RSpec.describe "read-only MCP tools" do
  def tool_payload(klass, **arguments)
    JSON.parse(klass.new(**arguments).call.contents.first.text)
  end

  describe GetAccountLeaseTool do
    it "reports no lease held when none was ever granted" do
      expect(tool_payload(described_class, account_id: "acc-none")).to eq(
        "account_id" => "acc-none", "venue" => "paper_exchange", "held" => false, "fence" => 0
      )
    end

    it "reports a live lease with its holder and fence" do
      AccountLeases.acquire!(account_id: "acc-live", holder_id: "agent-a", label: "Agent A", ttl_seconds: 60)

      expect(tool_payload(described_class, account_id: "acc-live")).to include(
        "held" => true, "holder_id" => "agent-a", "holder_label" => "Agent A", "fence" => 1
      )
    end

    it "reports a released lease as not held, with its release time" do
      lease = AccountLeases.acquire!(account_id: "acc-released", holder_id: "agent-a", label: "Agent A", ttl_seconds: 60)
      AccountLeases.release!(account_id: "acc-released", holder_id: "agent-a", fence: lease.fence)

      payload = tool_payload(described_class, account_id: "acc-released")
      expect(payload["held"]).to be(false)
      expect(payload["released_at"]).to be_present
    end
  end

  describe GetMarkPricesTool do
    before do
      allow(MarketData::MarkPriceStore).to receive(:get).with("BTCUSDT").and_return(65_000.5)
      allow(MarketData::MarkPriceStore).to receive(:get).with("ETHUSDT").and_return(nil)
      allow(MarketData::MarkPriceStore).to receive(:all).and_return({ "BTCUSDT" => 65_000.5 })
    end

    it "returns the live price for a symbol, normalised to upper case" do
      expect(tool_payload(described_class, symbol: "btcusdt")).to eq(
        "symbol" => "BTCUSDT", "price" => "65000.5", "status" => "live"
      )
    end

    it "reports a symbol with no known price as unavailable" do
      expect(tool_payload(described_class, symbol: "ETHUSDT")).to eq(
        "symbol" => "ETHUSDT", "price" => nil, "status" => "unavailable"
      )
    end

    it "returns every stored price when no symbol is given" do
      expect(tool_payload(described_class)).to eq("count" => 1, "prices" => { "BTCUSDT" => 65_000.5 })
    end
  end

  describe GetOpenPositionsTool do
    it "reports an unknown account rather than inventing one" do
      expect(tool_payload(described_class, account_id: "missing")).to eq(
        "error" => "account_not_found", "account_id" => "missing"
      )
    end

    it "lists the open positions the projection reports for the account" do
      create(:account, account_id: "acc-open")
      allow(Projections::PositionProjection).to receive(:for_account).with("acc-open")
        .and_return([ { symbol: "NIFTY", quantity: "50" } ])

      expect(tool_payload(described_class, account_id: "acc-open")).to eq(
        "account_id" => "acc-open", "count" => 1, "positions" => [ { "symbol" => "NIFTY", "quantity" => "50" } ]
      )
    end
  end

  describe GetRiskEventsTool do
    it "filters by account and event type" do
      create(:account, account_id: "acc-risk")
      create(:account, account_id: "acc-other")
      create(:risk_event, account_id: "acc-risk", event_type: "margin_exceeded", details: { "reason" => "over" })
      create(:risk_event, account_id: "acc-risk", event_type: "vix_gate_tripped")
      create(:risk_event, account_id: "acc-other", event_type: "margin_exceeded")

      payload = tool_payload(described_class, account_id: "acc-risk", event_type: "margin_exceeded")
      expect(payload["count"]).to eq(1)
      expect(payload["events"].first).to include(
        "account_id" => "acc-risk", "event_type" => "margin_exceeded", "details" => { "reason" => "over" }
      )
    end

    it "honours the requested limit" do
      create(:account, account_id: "acc-many")
      3.times { create(:risk_event, account_id: "acc-many") }

      expect(tool_payload(described_class, account_id: "acc-many", limit: 2)["count"]).to eq(2)
    end
  end

  describe GetPositionDetailsTool do
    before do
      create(:account, account_id: "acc-pos")
      allow(MarketData::MarkPriceStore).to receive(:get).and_return(nil)
    end

    it "returns a position found by id, with its protections" do
      position = create(:paper_position, account_id: "acc-pos", symbol: "NIFTY")
      PositionProtection.create!(
        paper_position_id: position.id, account_id: "acc-pos", instrument_id: "NIFTY",
        protection_type: PositionProtection::PROTECTION_TYPES.first, status: PositionProtection::STATUSES.first,
        quantity: 50, trigger_price: 95
      )

      payload = tool_payload(described_class, account_id: "acc-pos", position_id: position.id)
      expect(payload).to include("id" => position.id, "symbol" => "NIFTY")
      # No live mark, so the stored current_price (105) is the mark: (105 - 100) * 50 long
      expect(payload["unrealized_pnl"].to_f).to eq(250.0)
      expect(payload["protections"].size).to eq(1)
      expect(payload["protections"].first).to include("protection_type" => PositionProtection::PROTECTION_TYPES.first)
      expect(payload["protections"].first["trigger_price"].to_f).to eq(95.0)
    end

    it "finds a position by symbol, case-insensitively" do
      position = create(:paper_position, account_id: "acc-pos", symbol: "NIFTY")

      expect(tool_payload(described_class, account_id: "acc-pos", symbol: "nifty")["id"]).to eq(position.id)
    end

    it "falls back to the most recently updated position when neither id nor symbol is given" do
      create(:paper_position, account_id: "acc-pos", symbol: "NIFTY")

      expect(tool_payload(described_class, account_id: "acc-pos")["symbol"]).to eq("NIFTY")
    end

    it "reports a symbol the account does not hold as not found" do
      expect(tool_payload(described_class, account_id: "acc-pos", symbol: "BTCUSDT")).to eq(
        "error" => "position_not_found", "account_id" => "acc-pos"
      )
    end
  end

  describe GetClosedPositionsTool do
    it "reports an unknown account" do
      expect(tool_payload(described_class, account_id: "missing")).to eq(
        "error" => "account_not_found", "account_id" => "missing"
      )
    end

    it "returns the account's recent trades with their order details" do
      create(:account, account_id: "acc-trades")
      order = create(:paper_order, account_id: "acc-trades", symbol: "NIFTY")
      position = create(:paper_position, account_id: "acc-trades", symbol: "NIFTY")
      create(:paper_trade, paper_order: order, paper_position: position, quantity: 50, price: 101.5)

      payload = tool_payload(described_class, account_id: "acc-trades", limit: 5)
      expect(payload["count"]).to eq(1)
      expect(payload["trades"].first).to include("order_id" => order.id, "symbol" => "NIFTY", "side" => "buy")
      expect(payload["trades"].first["price"].to_f).to eq(101.5)
    end
  end

  describe GetOptionChainTool do
    it "returns the latest quotes for an underlying, filtered by expiry" do
      create(:option_snapshot, underlying: "NIFTY", symbol: "NIFTY27JAN25000C", expiry_date: Date.new(2027, 1, 28),
        strike_price: 25_000, option_type: "CE", ltp: 150.5, delta: 0.45)
      create(:option_snapshot, underlying: "NIFTY", symbol: "NIFTY27FEB25000C", expiry_date: Date.new(2027, 2, 25),
        strike_price: 25_000, option_type: "CE")
      create(:option_snapshot, underlying: "BANKNIFTY", symbol: "BANKNIFTY27JAN50000P", expiry_date: Date.new(2027, 1, 28),
        strike_price: 50_000, option_type: "PE")

      payload = tool_payload(described_class, underlying: "nifty", expiry_date: "2027-01-28", limit: 10)
      expect(payload["count"]).to eq(1)
      expect(payload["options"].first).to include(
        "symbol" => "NIFTY27JAN25000C", "underlying" => "NIFTY", "expiry_date" => "2027-01-28", "option_type" => "CE"
      )
      expect(payload["options"].first["ltp"].to_f).to eq(150.5)
      expect(payload["options"].first["delta"].to_f).to eq(0.45)
    end
  end

  describe GetMarketStructureTool do
    it "returns the snapshots for a symbol and timeframe" do
      MarketStructureSnapshot.create!(symbol: "BTCUSDT", timeframe: "5m", trend: "bullish", as_of: 1.hour.ago,
        bullish_fvg_count: 2, bearish_fvg_count: 1, last_bos: true)
      MarketStructureSnapshot.create!(symbol: "BTCUSDT", timeframe: "1h", trend: "bearish", as_of: 1.hour.ago)
      MarketStructureSnapshot.create!(symbol: "ETHUSDT", timeframe: "5m", trend: "bullish", as_of: 1.hour.ago)

      payload = tool_payload(described_class, symbol: "btcusdt", timeframe: "5m")
      expect(payload["count"]).to eq(1)
      expect(payload["snapshots"].first).to include(
        "symbol" => "BTCUSDT", "timeframe" => "5m", "trend" => "bullish",
        "bullish_fvg_count" => 2, "bearish_fvg_count" => 1, "last_bos" => true
      )
    end
  end
end
