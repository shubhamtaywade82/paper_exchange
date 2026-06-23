require 'rails_helper'

RSpec.describe Api::OrdersController, type: :controller do
  let(:account_id) { 'ACC-TEST' }

  let(:valid_attrs) do
    { symbol: 'RELIANCE', side: 'buy', quantity: 10, order_type: 'market', instrument_type: 'EQUITY' }
  end

  let(:invalid_attrs) { valid_attrs.merge(side: 'bad_side') }

  before do
    create(:account, account_id: account_id)
    request.headers['X-Account-Id'] = account_id
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a PaperOrder and returns 201' do
        expect {
          post :create, params: { order: valid_attrs.slice(:symbol, :side, :quantity, :order_type, :instrument_type) }
        }.to change(::PaperExchange::PaperOrder, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable_content' do
        post :create, params: { order: invalid_attrs.slice(:symbol, :side, :quantity, :order_type, :instrument_type) }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
