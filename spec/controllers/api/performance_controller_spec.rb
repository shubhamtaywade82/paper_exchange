require 'rails_helper'

RSpec.describe 'Api::Performance', type: :request do
  let(:account_id) { 'ACC-TEST' }
  before do
    create(:account, account_id: account_id)
  end

  it 'returns performance metrics' do
    get '/api/performance', params: { account_id: account_id }, headers: { 'X-Account-Id' => account_id }, as: :json
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json).to have_key('unrealized_pnl')
    expect(json).to have_key('realized_pnl')
  end
end
