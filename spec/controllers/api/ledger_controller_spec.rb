require 'rails_helper'

RSpec.describe Api::LedgerController, type: :controller do
  let(:account_id) { 'ACC-TEST' }
  before { create(:account, account_id: account_id) }

  describe 'GET #index' do
    it 'returns ledger entries in the pagination envelope' do
      create(:ledger_entry, account_id: account_id)
      get :index, params: { account_id: account_id }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include('data' => be_an(Array), 'next_cursor' => nil)
      expect(json['data'].first['event_type']).to eq('TRADE')
    end
  end
end
