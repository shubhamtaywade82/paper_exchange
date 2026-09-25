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

  describe 'GET #show' do
    # M7 regression guard: params[:id] is always a String; the old
    # `p[:id] == params[:id]` compared Integer to String and never matched,
    # so every request returned 404 after projecting the whole account.
    let!(:position) { create(:paper_position, account_id: account_id, symbol: 'NIFTY') }

    it 'returns the projected position for a valid id (String params match)' do
      get :show, params: { account_id: account_id, id: position.id }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(position.id)
      expect(json['symbol']).to eq('NIFTY')
      expect(json).to include('net_quantity', 'average_price', 'liquidation_price', 'unrealized_pnl')
    end

    it 'returns 404 for an unknown id' do
      get :show, params: { account_id: account_id, id: 999_999 }
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Position not found')
    end

    it 'returns 404 for a position belonging to another account (no existence oracle)' do
      create(:account, account_id: 'ACC-OTHER')
      other = create(:paper_position, account_id: 'ACC-OTHER', symbol: 'BANKNIFTY')

      get :show, params: { account_id: account_id, id: other.id }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'Position not found')
    end
  end
end
