require 'rails_helper'

# Prod-hardening (NEW-16): the deep health probe is what a load balancer should
# point at instead of /up (which only verifies Rails booted). These specs pin
# the 200/503 contract and the per-check shape so an operator wiring an LB to
# /health gets a stable signal, and so a regression that makes /health always
# return 200 (defeating its purpose) is caught.
RSpec.describe HealthController, type: :controller do
  describe 'GET #show' do
    it 'returns 200 with status ok when all dependencies are reachable' do
      # Stub Redis so the spec does not depend on a live Redis being present
      # at test time (postgres + solid_queue are exercised via the test DB).
      allow(MarketData::MarkPriceStore).to receive(:redis_healthy?).and_return(true)

      get :show

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('ok')
      expect(json['checks']).to include('postgres', 'redis', 'solid_queue')
    end

    it 'returns 503 with status degraded when Redis is unreachable' do
      allow(MarketData::MarkPriceStore).to receive(:redis_healthy?).and_return(false)

      get :show

      expect(response).to have_http_status(:service_unavailable)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('degraded')
      expect(json['checks']['redis']).to eq(false)
    end

    it 'does not require the X-API-Key (unauthenticated for LB probes)' do
      # HealthController inherits from ApplicationController (not Api::Base),
      # so it has no authenticate_api_key! before_action. A request without
      # the X-API-Key header should still succeed (not 401) so a load balancer
      # can probe it without the operator secret.
      get :show
      expect(response).not_to have_http_status(:unauthorized)
    end
  end
end
