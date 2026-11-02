require 'rails_helper'

RSpec.describe 'Backtest datasets API', type: :request do
  let(:headers) { { 'X-API-Key' => ENV.fetch('PAPER_EXCHANGE_API_KEY') } }
  let(:bars) do
    [
      { bar_at: '2026-11-02T03:45:00Z', open: 100, high: 101, low: 99, close: 100.5, volume: 10 },
      { bar_at: '2026-11-02T03:50:00Z', open: 100.5, high: 102, low: 100, close: 101, volume: 12 },
      { bar_at: '2026-11-02T03:55:00Z', open: 101, high: 101.5, low: 99.5, close: 100, volume: 8 }
    ]
  end
  let(:payload) { { name: 'reliance 5m', symbol: 'RELIANCE', instrument_type: 'EQUITY', timeframe: '5m', bars: bars } }

  it 'rejects requests without the API key' do
    get '/api/backtest_datasets'

    expect(response).to have_http_status(:unauthorized)
  end

  describe 'POST /api/backtest_datasets' do
    it 'stores the dataset and its bars and returns 201 with the metadata' do
      post '/api/backtest_datasets', params: payload, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include('symbol' => 'RELIANCE', 'currency' => 'INR', 'bars_count' => 3, 'timeframe' => '5m')
      expect(body['fingerprint']).to match(/\A\h{64}\z/)
      expect(Backtest::DatasetBar.where(backtest_dataset_id: body['id']).count).to eq(3)
    end

    it 'returns 422 with each reason when the bars are invalid' do
      bad = payload.merge(bars: [ bars[0].merge(high: 98), bars[1] ])

      post '/api/backtest_datasets', params: bad, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['details'].join).to include('OHLC is inconsistent')
    end

    it 'accepts CSV text as an alternative to a bar array' do
      csv = "bar_at,open,high,low,close,volume\n2026-11-02T03:45:00Z,100,101,99,100.5,10\n2026-11-02T03:50:00Z,100.5,102,100,101,12\n"

      post '/api/backtest_datasets', params: payload.except(:bars).merge(csv: csv), headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['bars_count']).to eq(2)
    end
  end

  describe 'GET /api/backtest_datasets' do
    it 'lists datasets newest first with a cursor envelope' do
      Backtest::DatasetManager.create!(payload)

      get '/api/backtest_datasets', headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].size).to eq(1)
      expect(body).to have_key('next_cursor')
    end

    it 'returns 404 for an unknown dataset' do
      get '/api/backtest_datasets/999999', headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/backtest_datasets/:id' do
    it 'deletes an unused dataset' do
      dataset = Backtest::DatasetManager.create!(payload)

      delete "/api/backtest_datasets/#{dataset.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Backtest::Dataset.exists?(dataset.id)).to be(false)
    end

    it 'refuses to delete a dataset that a run still uses' do
      dataset = Backtest::DatasetManager.create!(payload)
      Backtest::Run.create!(Backtest::RunValidator.call(
        dataset_id: dataset.id, name: 'uses it', sizing: { type: 'fixed', quantity: 1 },
        strategy: { key: 'signal_replay', params: { signals: [] } }
      ))

      delete "/api/backtest_datasets/#{dataset.id}", headers: headers

      expect(response).to have_http_status(:conflict)
      expect(Backtest::Dataset.exists?(dataset.id)).to be(true)
    end
  end
end
