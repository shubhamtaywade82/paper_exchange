require 'rails_helper'

RSpec.describe Api::PerformanceController, type: :controller do
  let(:account_id) { 'ACC-TEST' }
  before { create(:account, account_id: account_id) }

  describe 'GET #show' do
    it 'returns performance metrics' do
      get :show, params: { account_id: account_id }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('equity')
      expect(json).to have_key('drawdown')
    end
  end
end
