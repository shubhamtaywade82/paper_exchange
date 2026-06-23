require 'rails_helper'

RSpec.describe Api::RiskEventsController, type: :controller do
  let(:account_id) { 'ACC-TEST' }
  before do
    create(:account, account_id: account_id)
    create(:risk_event, account_id: account_id, event_type: 'TEST', details: {})
    request.headers['X-Account-Id'] = account_id
  end

  describe 'GET #index' do
    it 'returns risk events' do
      get :index
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
    end
  end
end
