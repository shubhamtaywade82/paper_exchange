require "rails_helper"

# The account lease: how a single writer takes a live account, renews it, and gives it back. Every write to a live account
# must present the lease, and the venue refuses any write that does not hold the live fence.
RSpec.describe "Account leases", type: :request do
  let(:api_key) { ENV.fetch("PAPER_EXCHANGE_API_KEY") }
  let(:account_id) { "ACC-LEASE-API" }
  let(:headers) { { "X-API-Key" => api_key, "X-Account-Id" => account_id } }

  def acquire(holder: "agent-1", label: "agent-1", ttl: nil)
    body = { holder_id: holder, holder_label: label }
    body[:ttl_seconds] = ttl unless ttl.nil?
    post "/api/account/lease", headers: headers, params: body, as: :json
  end

  def leased_headers(holder: "agent-1", fence:)
    headers.merge("X-Lease-Holder" => holder, "X-Lease-Fence" => fence.to_s)
  end

  # Ages the lease past its expiry on the database clock, the only clock a lease answers to.
  def expire_now!
    AccountLease.where(account_id: account_id).update_all("expires_at = now() - interval '1 second'")
  end

  describe "POST /api/account/lease" do
    it "grants a free account and returns the fence the holder must present" do
      acquire
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("account_id" => account_id, "holder_id" => "agent-1", "fence" => 1, "live" => true)
    end

    it "refuses a second holder with 409 lease_held, naming the holder and when its lease lapses" do
      acquire
      acquire(holder: "agent-2", label: "agent-2")
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to include("error" => "lease_held", "holder_label" => "agent-1")
      expect(response.parsed_body["expires_at"]).to be_present
    end

    it "renews the same holder's live lease at the same fence" do
      acquire
      acquire
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["fence"]).to eq(1)
    end

    it "requires a holder_id" do
      acquire(holder: "")
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to match(/holder_id is required/)
    end

    it "refuses a ttl outside 10 to 600 seconds" do
      acquire(ttl: 9)
      expect(response).to have_http_status(:bad_request)
      acquire(ttl: 601)
      expect(response).to have_http_status(:bad_request)
    end

    it "refuses to take a lease without naming the account" do
      post "/api/account/lease", headers: { "X-API-Key" => api_key }, params: { holder_id: "agent-1" }, as: :json
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to match(/account_required/)
    end
  end

  describe "PUT /api/account/lease" do
    it "extends the live lease under the presented holder and fence" do
      acquire
      put "/api/account/lease", headers: leased_headers(fence: 1), params: { ttl_seconds: 120 }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("holder_id" => "agent-1", "fence" => 1, "live" => true)
    end

    it "refuses a heartbeat that presents no lease headers: 409 lease_required" do
      acquire
      put "/api/account/lease", headers: headers, params: {}, as: :json
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]).to eq("lease_required")
    end

    it "refuses a heartbeat under a fence that a takeover has superseded: 409 lease_lost" do
      acquire
      expire_now!
      acquire(holder: "agent-2", label: "agent-2")
      put "/api/account/lease", headers: leased_headers(fence: 1), params: {}, as: :json
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]).to eq("lease_lost")
    end
  end

  describe "DELETE /api/account/lease" do
    it "releases the lease so the next holder takes it at the next fence" do
      acquire
      delete "/api/account/lease", headers: leased_headers(fence: 1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("released" => true)

      acquire(holder: "agent-2", label: "agent-2")
      expect(response.parsed_body["fence"]).to eq(2)
    end

    it "releases nothing under a superseded fence" do
      acquire
      expire_now!
      acquire(holder: "agent-2", label: "agent-2")
      delete "/api/account/lease", headers: leased_headers(fence: 1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("released" => false)
    end

    it "requires the lease headers: 409 lease_required" do
      acquire
      delete "/api/account/lease", headers: headers
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]).to eq("lease_required")
    end
  end

  describe "GET /api/account/lease" do
    it "reads the lease without presenting one" do
      acquire
      get "/api/account/lease", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("holder_id" => "agent-1", "live" => true)
    end

    it "reports 404 when no lease has ever been granted" do
      get "/api/account/lease", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "reports the lease as not live once it has lapsed" do
      acquire
      expire_now!
      get "/api/account/lease", headers: headers
      expect(response.parsed_body["live"]).to be(false)
    end
  end

  describe "fencing writes to a live account" do
    let!(:live_account) { create(:account, account_id: account_id, margin: 10_000.0, available_balance: 10_000.0) }

    it "refuses a write that presents no lease: 409 lease_required, and the account is untouched" do
      post "/api/account/reset", headers: headers, params: { margin: 500 }
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]).to eq("lease_required")
      expect(Account.find_by!(account_id: account_id).margin).to eq(10_000)
    end

    it "refuses a write under a fence that a takeover has superseded: 409 lease_lost, and the account is untouched" do
      acquire
      expire_now!
      acquire(holder: "agent-2", label: "agent-2")
      post "/api/account/reset", headers: leased_headers(fence: 1), params: { margin: 500 }
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]).to eq("lease_lost")
      expect(Account.find_by!(account_id: account_id).margin).to eq(10_000)
    end

    it "lets the live holder write under the live fence" do
      acquire
      post "/api/account/reset", headers: leased_headers(fence: 1), params: { margin: 500 }
      expect(response).to have_http_status(:ok)
      expect(Account.find_by!(account_id: account_id).margin).to eq(500)
    end

    it "refuses a write that does not name its account: 400 account_required" do
      post "/api/account/reset", headers: { "X-API-Key" => api_key }, params: { margin: 500 }
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to match(/account_required/)
    end

    it "does not fence reads, so monitoring reads a leased account freely" do
      acquire
      get "/api/account", headers: headers.except("X-Lease-Holder")
      expect(response).to have_http_status(:ok)
    end

    it "does not fence a simulated account, whose single simulation has one writer" do
      create(:account, account_id: "ACC-SIM-API", simulated: true, margin: 10_000.0, available_balance: 10_000.0)
      post "/api/account/reset", headers: { "X-API-Key" => api_key, "X-Account-Id" => "ACC-SIM-API" }, params: { margin: 500 }
      expect(response).to have_http_status(:ok)
    end
  end
end
