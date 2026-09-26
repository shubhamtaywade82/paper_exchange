require 'rails_helper'

# POST /api/market_events — feed-owner tick ingestion into the Redis
# stream (all-or-nothing boundary validation, audit M3 rules); GET —
# newest-first read-back with a stream cursor. TickProcessor is stubbed
# here (CI has no Redis); the stream semantics live in
# tick_processor_spec.rb.
RSpec.describe 'Market events API', type: :request do
  let(:api_key) { ENV.fetch('PAPER_EXCHANGE_API_KEY') }
  let(:headers) { { 'X-API-Key' => api_key } }

  describe 'POST /api/market_events' do
    it 'accepts a single tick (201) with the symbol normalized' do
      allow(MarketData::TickProcessor).to receive(:enqueue).and_return('1700000000000-1')

      post '/api/market_events', params: {
        symbol: 'btcusdt', price: '65123.45', bid: '65120.0', ask: '65125.0',
        quantity: '0.5', timestamp: '2026-09-26T10:00:00Z', source: 'binance'
      }, headers: headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['accepted']).to eq(1)
      expect(body['data'].first).to include(
        'symbol' => 'BTCUSDT', 'stream_id' => '1700000000000-1', 'source' => 'binance'
      )
      expect(MarketData::TickProcessor).to have_received(:enqueue).once
    end

    it 'accepts a batch under { events: [...] }' do
      allow(MarketData::TickProcessor).to receive(:enqueue).and_return('1700000000000-1')

      post '/api/market_events', params: { events: [
        { symbol: 'BTCUSDT', ltp: '65000' },
        { symbol: 'ETHUSDT', ltp: '3000', timestamp: '2026-09-26T10:00:00Z' }
      ] }, headers: headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['accepted']).to eq(2)
    end

    it 'rejects a garbage price 422 and enqueues NOTHING (all-or-nothing)' do
      allow(MarketData::TickProcessor).to receive(:enqueue)

      post '/api/market_events', params: { events: [
        { symbol: 'BTCUSDT', ltp: '65000' },
        { symbol: 'ETHUSDT', ltp: 'garbage' }
      ] }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to include('ETHUSDT')
      expect(MarketData::TickProcessor).not_to have_received(:enqueue)
    end

    it 'rejects a zero/negative price like mark_prices (audit M3)' do
      allow(MarketData::TickProcessor).to receive(:enqueue)

      post '/api/market_events', params: { symbol: 'BTCUSDT', price: '0' }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(MarketData::TickProcessor).not_to have_received(:enqueue)
    end

    it 'requires a symbol and at least one price field' do
      allow(MarketData::TickProcessor).to receive(:enqueue)

      post '/api/market_events', params: { price: '100' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)

      post '/api/market_events', params: { symbol: 'BTCUSDT', quantity: '1' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)

      expect(MarketData::TickProcessor).not_to have_received(:enqueue)
    end

    it 'rejects an oversized batch' do
      allow(MarketData::TickProcessor).to receive(:enqueue)

      post '/api/market_events', params: { events: Array.new(501) { { symbol: 'BTCUSDT', ltp: '1' } } }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to include('batch too large')
    end

    it 'returns 503 (not 201) when the tick stream is unavailable' do
      allow(MarketData::TickProcessor).to receive(:enqueue).and_return(nil)

      post '/api/market_events', params: { symbol: 'BTCUSDT', ltp: '65000' }, headers: headers

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)['error']).to include('tick stream')
    end
  end

  describe 'GET /api/market_events' do
    it 'reads back the stream newest-first through the pagination envelope' do
      event = MarketData::MarketEvent.new(
        symbol: 'BTCUSDT', price: 65_000.0, ltp: 65_000.0,
        timestamp: Time.zone.parse('2026-09-26T10:00:00Z'), source: 'test'
      )
      allow(MarketData::TickProcessor).to receive(:read_last).and_return([ [ event ], '1699999999999-7' ])

      get '/api/market_events', params: { symbol: 'btcusdt', count: 50 }, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].first['symbol']).to eq('BTCUSDT')
      expect(body['next_cursor']).to eq('1699999999999-7')
      expect(MarketData::TickProcessor).to have_received(:read_last)
        .with(count: 50, symbol: 'BTCUSDT', before_id: nil)
    end

    it 'clamps count to 1..1000 with a default of 100' do
      allow(MarketData::TickProcessor).to receive(:read_last).and_return([ [], nil ])

      get '/api/market_events', params: { count: '99999' }, headers: headers
      expect(MarketData::TickProcessor).to have_received(:read_last).with(count: 1000, symbol: nil, before_id: nil)

      get '/api/market_events', params: { count: '0' }, headers: headers
      expect(MarketData::TickProcessor).to have_received(:read_last).with(count: 100, symbol: nil, before_id: nil)

      get '/api/market_events', params: { count: 'abc', before: '1700000000000-1' }, headers: headers
      expect(MarketData::TickProcessor).to have_received(:read_last).with(count: 100, symbol: nil, before_id: '1700000000000-1')
    end
  end
end
