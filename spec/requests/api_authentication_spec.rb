require 'rails_helper'

# Audit M2: every route group under /api must refuse unauthenticated
# requests with 401 and accept requests carrying the operator's X-API-Key.
# One route per controller group suffices — the check lives in
# Api::BaseController and runs before every action.
RSpec.describe 'API authentication (audit M2)', type: :request do
  let(:api_key) { ENV.fetch('PAPER_EXCHANGE_API_KEY') }
  let(:auth_headers) { { 'X-API-Key' => api_key } }

  describe 'without an X-API-Key header' do
    it 'returns 401 for every route group' do
      get '/api/orders'
      expect(response).to have_http_status(:unauthorized)

      get '/api/positions'
      expect(response).to have_http_status(:unauthorized)

      get '/api/ledger'
      expect(response).to have_http_status(:unauthorized)

      get '/api/risk_events'
      expect(response).to have_http_status(:unauthorized)

      get '/api/performance'
      expect(response).to have_http_status(:unauthorized)

      get '/api/account'
      expect(response).to have_http_status(:unauthorized)

      post '/api/mark_prices', params: { prices: { BTCUSDT: '65000' } }
      expect(response).to have_http_status(:unauthorized)

      post '/api/funding_events', params: { symbol: 'BTCUSDT', funding_rate: '0.0001' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'with a wrong X-API-Key' do
    it 'returns 401' do
      get '/api/orders', headers: { 'X-API-Key' => 'wrong-key' }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to include('API key')
    end
  end

  describe 'with the correct X-API-Key' do
    it 'authenticates — route groups respond with their normal statuses' do
      get '/api/orders', headers: auth_headers
      expect(response).to have_http_status(:ok)

      post '/api/mark_prices', params: { prices: { BTCUSDT: '65000' } }, headers: auth_headers
      expect(response).to have_http_status(:ok)

      post '/api/funding_events', params: { symbol: 'BTCUSDT', funding_rate: '0.0001' }, headers: auth_headers
      expect(response).to have_http_status(:accepted)

      # No "default" account row exists in this example, so the
      # authenticated response is the account controller's normal 404 —
      # proof the request passed the gate and reached the action.
      get '/api/account', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
