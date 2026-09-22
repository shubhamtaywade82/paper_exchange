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

    context 'with reduce_only' do
      let(:btc_order) do
        { symbol: 'BTCUSDT', side: 'buy', quantity: 0.1, order_type: 'market', instrument_type: 'CRYPTO_PERPETUAL',
          leverage: 5, margin_type: 'isolated', execution_price: 65_000.0 }
      end

      it 'returns 422 when there is no position to reduce' do
        expect {
          post :create, params: { order: btc_order.merge(side: 'sell', reduce_only: true) }
        }.not_to change(::PaperExchange::PaperOrder, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['error']).to match(/reduce_only/)
      end

      it 'closes an open position and clamps the quantity' do
        post :create, params: { order: btc_order }
        post :create, params: { order: btc_order.merge(side: 'sell', quantity: 1, reduce_only: true) }

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body).values_at('status', 'quantity').map(&:to_s)).to eq(%w[filled 0.1])
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
