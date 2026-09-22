require 'rails_helper'

RSpec.describe Api::FundingEventsController, type: :controller do
  describe 'POST #create' do
    it 'enqueues FundingJob with the pushed rate' do
      expect {
        post :create, params: { symbol: 'btcusdt', funding_rate: '0.0003', mark_price: '65000.0' }
      }.to have_enqueued_job(FundingJob).with('BTCUSDT', 0.0003, 65000.0)

      expect(response).to have_http_status(:accepted)
      expect(JSON.parse(response.body)['symbol']).to eq('BTCUSDT')
    end

    it 'defaults mark_price to nil when not supplied' do
      expect {
        post :create, params: { symbol: 'BTCUSDT', funding_rate: '0.0003' }
      }.to have_enqueued_job(FundingJob).with('BTCUSDT', 0.0003, nil)
    end

    it 'returns 400 when symbol is missing' do
      post :create, params: { funding_rate: '0.0003' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 when funding_rate is missing' do
      post :create, params: { symbol: 'BTCUSDT' }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
