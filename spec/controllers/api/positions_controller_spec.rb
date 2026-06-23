require 'rails_helper'

RSpec.describe Api::PositionsController, type: :controller do
  let(:account_id) { 'ACC-TEST' }
  before { create(:account, account_id: account_id) }

  describe 'GET #index' do
    it 'returns open positions' do
      create(:paper_position, account_id: account_id, symbol: 'NIFTY')
      get :index, params: { account_id: account_id }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
    end
  end
end
