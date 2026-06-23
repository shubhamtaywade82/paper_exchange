require 'rails_helper'

RSpec.describe Api::OrdersController, type: :controller do
  let(:account_id) { 'ACC-TEST' }
  let(:valid_attrs) do
    {
      account_id: account_id,
      symbol: 'RELIANCE',
      side: 'buy',
      quantity: 10,
      order_type: 'market',
      instrument_type: 'EQUITY'
    }
  end
    {
      account_id: account_id,
      symbol: 'RELIANCE',
      side: 'buy',
      quantity: 10,
      order_type: 'market',
      instrument_type: 'EQUITY'
    }
  end

  before { create(:account, account_id: account_id) }

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a PaperOrder' do
        expect { post :create, params: { order: valid_attrs } }.to change(PaperExchange::PaperOrder, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid params' do
      let(:invalid_attrs) { valid_attrs.merge(side: 'bad_side') }
      it 'returns unprocessable_entity' do
        post :create, params: { order: invalid_attrs }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
