require 'rails_helper'

# A run's lifecycle over HTTP: listing, finishing early, the answers that refuse
# a run definition or an action on it, and a run the replay fails.
RSpec.describe 'Backtest run lifecycle API', type: :request do
  let(:headers) { { 'X-API-Key' => ENV.fetch('PAPER_EXCHANGE_API_KEY') } }
  let(:flat) { [ 100, 101, 99, 100 ] }
  let(:dataset) { create_dataset!([ flat, flat, flat ]) }

  def create_external_run!(**overrides)
    post '/api/backtest_runs', headers: headers, as: :json, params: {
      dataset_id: dataset.id, name: 'lifecycle', mode: 'external', initial_capital: 10_000
    }.merge(overrides)
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)
  end

  describe 'GET /api/backtest_runs' do
    it 'lists runs newest first with a cursor envelope' do
      run = create_external_run!

      get '/api/backtest_runs', headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].map { |r| r['id'] }).to include(run['id'])
      expect(body).to have_key('next_cursor')
    end
  end

  describe 'POST /api/backtest_runs' do
    it 'answers 422 when the name is blank once trimmed' do
      post '/api/backtest_runs', headers: headers, as: :json, params: {
        dataset_id: dataset.id, name: '   ', mode: 'external'
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body).to_s).to include("Name can't be blank")
    end
  end

  describe 'POST /api/backtest_runs/:id/finish' do
    it 'ends an external run early and stores its results' do
      run = create_external_run!
      post "/api/backtest_runs/#{run['id']}/advance", headers: headers
      expect(response).to have_http_status(:ok)

      post "/api/backtest_runs/#{run['id']}/finish", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include('status' => 'completed', 'bars_processed' => 1)
      expect(body['diagnostics']).to include('finished_reason' => 'requested')
    end

    it 'answers 409 when the run is already finished' do
      run = create_external_run!
      post "/api/backtest_runs/#{run['id']}/finish", headers: headers

      post "/api/backtest_runs/#{run['id']}/finish", headers: headers

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)['error']).to include('already finished')
    end
  end

  describe 'POST /api/backtest_runs/:id/advance on a run whose protective stop is refused' do
    it 'answers 409 with the reason, and the run reads as failed afterwards' do
      run = create_external_run!
      post '/api/orders', headers: headers.merge('X-Account-Id' => run['account_id']), as: :json, params: {
        symbol: 'RELIANCE', side: 'buy', quantity: 10, order_type: 'market', instrument_type: 'EQUITY', stop_loss: 95
      }
      expect(response).to have_http_status(:accepted)
      allow_any_instance_of(Exchange::PaperExchange).to receive(:submit_order).and_wrap_original do |original, attrs|
        if attrs[:reduce_only] && attrs[:order_kind] == 'stop_loss'
          ::PaperExchange::PaperOrder.create!(
            account_id: attrs[:account_id], symbol: attrs[:symbol], instrument_type: attrs[:instrument_type],
            side: attrs[:side], quantity: attrs[:quantity], order_kind: 'stop_loss',
            trigger_price: attrs[:trigger_price], status: :rejected, rejection_reason: 'refused by the exchange'
          )
        else
          original.call(attrs)
        end
      end

      post "/api/backtest_runs/#{run['id']}/advance", headers: headers

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)['error']).to start_with('run failed: ')
      expect(JSON.parse(response.body)['error']).to include('stop order could not be placed')

      get "/api/backtest_runs/#{run['id']}", headers: headers
      expect(JSON.parse(response.body)['status']).to eq('failed')
    end
  end
end
