require 'rails_helper'

RSpec.describe Api::MarkPricesController, type: :controller do
  describe 'POST #create' do
    it 'stores every pushed price and returns them normalized' do
      post :create, params: { prices: { btcusdt: '65123.45', ETHUSDT: '3200.10' } }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['updated']).to eq('BTCUSDT' => 65123.45, 'ETHUSDT' => 3200.10)
      expect(MarketData::MarkPriceStore.get('BTCUSDT')).to eq(65123.45)
    end

    it 'triggers a liquidation check for a breached position' do
      account = create(:account, account_id: 'ACC-MARKPRICE')
      position = create(:paper_position,
        account_id: account.account_id,
        symbol: 'BTCUSDT',
        side: :long,
        quantity: 1,
        avg_price: 60_000.0,
        leverage: 10,
        liquidation_price: 54_000.0)

      expect {
        post :create, params: { prices: { BTCUSDT: '53000' } }
      }.to have_enqueued_job(LiquidationJob).with(position.id, 53_000.0)
    end

    it 'returns 400 when prices is missing' do
      post :create, params: {}
      expect(response).to have_http_status(:bad_request)
    end

    it 'ignores blank price values' do
      post :create, params: { prices: { BTCUSDT: '' } }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['updated']).to eq({})
    end

    # M3 regression guard: a garbage price used to become 0.0 via .to_f,
    # which trivially breaches every long's liquidation price.
    it 'rejects the whole request 422 when any price is garbage, retains prior prices, and enqueues nothing' do
      MarketData::MarkPriceStore.set('BTCUSDT', 65_000.0)

      expect {
        post :create, params: { prices: { BTCUSDT: 'garbage' } }
      }.not_to have_enqueued_job(LiquidationJob)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to include('BTCUSDT')
      expect(MarketData::MarkPriceStore.get('BTCUSDT')).to eq(65_000.0)
    end

    it 'rejects zero, negative, non-finite, and out-of-band prices' do
      [ '0', '-1', '1e400', '9999999999999999' ].each do |bad|
        post :create, params: { prices: { BTCUSDT: bad } }
        expect(response).to have_http_status(:unprocessable_content), "expected 422 for #{bad.inspect}"
      end
    end

    it 'accepts prices at the band ceiling' do
      post :create, params: { prices: { BTCUSDT: '1000000000000000' } }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['updated']['BTCUSDT']).to eq(1e15)
    end
  end
end
