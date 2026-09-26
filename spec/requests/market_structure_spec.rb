require 'rails_helper'

RSpec.describe 'Market structure API', type: :request do
  let(:api_key) { ENV.fetch('PAPER_EXCHANGE_API_KEY') }
  let(:headers) { { 'X-API-Key' => api_key } }

  describe 'POST /api/market_structure' do
    it 'creates a snapshot with defaults (201)' do
      post '/api/market_structure', params: { symbol: 'btcusdt' }, headers: headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include(
        'symbol' => 'BTCUSDT', 'timeframe' => '5m', 'trend' => nil,
        'last_bos' => false, 'last_choch' => false,
        'bullish_fvg_count' => 0, 'bearish_fvg_count' => 0
      )
    end

    it 'stores the full SMC payload' do
      post '/api/market_structure', params: {
        symbol: 'BTCUSDT', timeframe: '15m', trend: 'bullish',
        bos: true, choch: false, bullish_fvg_count: 2, bearish_fvg_count: 1,
        liquidity_sweep: 'sell_side', order_block: 'bullish_ob',
        premium_discount: 'premium', as_of: '2026-09-26T10:00:00Z'
      }, headers: headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include('trend' => 'bullish', 'last_bos' => true,
                             'liquidity_sweep' => 'sell_side', 'order_block' => 'bullish_ob',
                             'premium_discount' => 'premium')
    end

    it 'rejects an unknown trend, negative fvg count and a bad as_of with 422' do
      post '/api/market_structure', params: { symbol: 'BTCUSDT', trend: 'moonways' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)

      post '/api/market_structure', params: { symbol: 'BTCUSDT', bullish_fvg_count: '-1' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)

      post '/api/market_structure', params: { symbol: 'BTCUSDT', as_of: 'not-a-time' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'requires a symbol' do
      post '/api/market_structure', params: { trend: 'bullish' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /api/market_structure' do
    it 'returns the latest snapshot for a symbol (404 when none)' do
      post '/api/market_structure', params: { symbol: 'BTCUSDT', trend: 'bearish' }, headers: headers
      post '/api/market_structure', params: { symbol: 'BTCUSDT', trend: 'bullish' }, headers: headers

      get '/api/market_structure', params: { symbol: 'BTCUSDT' }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['trend']).to eq('bullish')

      get '/api/market_structure', params: { symbol: 'NOPEUSDT' }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'lists the latest snapshot per symbol when no symbol is given' do
      post '/api/market_structure', params: { symbol: 'BTCUSDT', trend: 'bearish' }, headers: headers
      post '/api/market_structure', params: { symbol: 'ETHUSDT', trend: 'range', timeframe: '1m' }, headers: headers

      get '/api/market_structure', params: { timeframe: '1m' }, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['timeframe']).to eq('1m')
      expect(body['data'].map { |s| s['symbol'] }).to eq(%w[ETHUSDT]) # BTCUSDT only has a 5m snapshot
    end
  end
end
