require 'rails_helper'

RSpec.describe Api::PerformanceController, type: :controller do
  let(:account_id) { 'ACC-TEST' }

  before do
    create(:account, account_id: account_id)
    request.headers['X-Account-Id'] = account_id
  end

  it 'returns performance metrics' do
    get :show, params: { account_id: account_id }
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json).to have_key('unrealized_pnl')
    expect(json).to have_key('realized_pnl')
  end
end
