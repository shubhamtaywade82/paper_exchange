require 'rails_helper'

RSpec.describe Api::AccountsController, type: :controller do
  let(:account_id) { 'ACC-TEST' }

  before { request.headers['X-Account-Id'] = account_id }

  describe 'GET #show' do
    it 'returns 404 when the account does not exist' do
      get :show
      expect(response).to have_http_status(:not_found)
    end

    context 'with an existing account' do
      before { create(:account, account_id: account_id, margin: 100_000.0) }

      it 'returns the wallet split and live equity' do
        get :show
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['account_id']).to eq(account_id)
        expect(json['available_balance'].to_f).to eq(100_000.0)
        expect(json['locked_margin'].to_f).to eq(0.0)
        expect(json['equity'].to_f).to eq(100_000.0)
      end

      it 'reflects margin locked against an open leveraged position' do
        position = create(:paper_position,
          account_id: account_id,
          symbol: 'BTCUSDT',
          side: :long,
          quantity: 1,
          avg_price: 60_000.0,
          current_price: 60_000.0,
          leverage: 10)
        Exchange::MarginEngine.sync_position!(position, account_id: account_id)

        get :show
        json = JSON.parse(response.body)
        expect(json['locked_margin'].to_f).to eq(6_000.0)
        expect(json['available_balance'].to_f).to eq(94_000.0)
      end
    end
  end
end
