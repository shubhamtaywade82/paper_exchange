require 'rails_helper'

RSpec.describe Api::RiskEventsController, type: :controller do
  let(:account_id) { 'ACC-TEST' }
  before { create(:account, account_id: account_id) }

  describe 'GET #index' do
    it 'returns risk events' do
      create(:risk_event, account_id: account_id)
      get :index, params: { account_id: account_id }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
    end
  end
end
