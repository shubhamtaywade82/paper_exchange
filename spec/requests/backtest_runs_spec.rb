require 'rails_helper'

RSpec.describe 'Backtest runs API', type: :request do
  let(:headers) { { 'X-API-Key' => ENV.fetch('PAPER_EXCHANGE_API_KEY') } }
  let(:ohlc) do
    [
      [ 100, 101, 99, 100 ],
      [ 100, 102, 99, 101 ],
      [ 101, 103, 100, 102 ],
      [ 102, 111, 101, 110 ],
      [ 110, 111, 109, 110 ]
    ]
  end
  let(:dataset) { create_dataset!(ohlc) }
  let(:run_payload) do
    {
      dataset_id: dataset.id,
      name: 'tp run',
      strategy: { key: 'signal_replay', params: { signals: [ { ts: inside_bar(2), action: 'buy', quantity: 10, stop_loss: 95, take_profit: 110 } ] } },
      sizing: { type: 'fixed', quantity: 10 },
      initial_capital: 10_000
    }
  end

  describe 'POST /api/backtest_runs' do
    it 'creates a pending run on its own paper account and returns 201' do
      post '/api/backtest_runs', params: run_payload, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include('status' => 'pending', 'dataset_id' => dataset.id)
      expect(body['account_id']).to start_with('backtest-')
      expect(body['strategy']).to include('key' => 'signal_replay')
    end

    it 'returns 422 with details for an invalid definition' do
      post '/api/backtest_runs', params: run_payload.merge(sizing: { type: 'fixed', quantity: 0.5 }, dataset_id: 0), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['details']).to be_present
    end

    it 'returns 422 when the strategy is unknown' do
      post '/api/backtest_runs', params: run_payload.merge(strategy: { key: 'moon_shot' }), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['details'].join).to include('unknown strategy')
    end
  end

  describe 'POST /api/backtest_runs/:id/execute' do
    it 'queues the run for the worker and returns 202' do
      run = Backtest::Run.create!(Backtest::RunValidator.call(run_payload))

      expect {
        post "/api/backtest_runs/#{run.id}/execute", headers: headers
      }.to have_enqueued_job(BacktestRunJob).with(run.id)

      expect(response).to have_http_status(:accepted)
    end

    it 'refuses to execute a run that already finished, until it is reset' do
      run = Backtest::Run.create!(Backtest::RunValidator.call(run_payload))
      execute_run!(run)

      post "/api/backtest_runs/#{run.id}/execute", headers: headers

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)['error']).to include('reset it before executing')
    end
  end

  describe 'results' do
    let!(:run) do
      Backtest::Run.create!(Backtest::RunValidator.call(run_payload)).tap { |r| execute_run!(r) }
    end

    it 'returns the metrics and diagnostics on show' do
      get "/api/backtest_runs/#{run.id}", headers: headers

      body = JSON.parse(response.body)
      expect(body['status']).to eq('completed')
      expect(body['metrics']).to include('total_trades' => 1, 'winning_trades' => 1, 'profit_factor_capped' => true)
      expect(body['diagnostics']).to include('cancelled_at_end' => 0)
    end

    it 'pages the trades with their exit reasons' do
      get "/api/backtest_runs/#{run.id}/trades", headers: headers

      trade = JSON.parse(response.body)['data'].sole
      expect(trade).to include('direction' => 'long', 'entry_price' => 102.0, 'exit_price' => 110.0,
        'exit_reason' => 'take_profit', 'gross_pnl' => 80.0)
    end

    it 'returns the equity curve oldest first' do
      get "/api/backtest_runs/#{run.id}/equity", headers: headers

      curve = JSON.parse(response.body)['data']
      expect(curve.size).to eq(ohlc.size)
      expect(curve.first).to include('equity' => 10_000.0, 'in_market' => false)
    end

    it 'lists the paper orders and the position state of the run account' do
      get "/api/backtest_runs/#{run.id}/orders", headers: headers
      orders = JSON.parse(response.body)['data']

      # Entry filled, take-profit filled, and the protective stop cancelled by the OCO rule.
      expect(orders.map { |o| o['status'] }.sort).to eq(%w[cancelled filled filled])

      get "/api/backtest_runs/#{run.id}/positions", headers: headers
      expect(JSON.parse(response.body)['data'].sole).to include('quantity' => 0.0)
    end
  end

  describe 'POST /api/backtest_runs/:id/reset' do
    it 'returns a completed run to pending and restores its balance' do
      run = Backtest::Run.create!(Backtest::RunValidator.call(run_payload))
      execute_run!(run)

      post "/api/backtest_runs/#{run.id}/reset", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('status' => 'pending', 'metrics' => {})
      expect(Account.find_by!(account_id: run.account_id).available_balance).to eq(10_000)
    end

    it 'refuses to reset a running run' do
      run = Backtest::Run.create!(Backtest::RunValidator.call(run_payload))
      run.update!(status: 'running')

      post "/api/backtest_runs/#{run.id}/reset", headers: headers

      expect(response).to have_http_status(:conflict)
    end
  end

  describe 'DELETE /api/backtest_runs/:id' do
    it 'deletes the run, its trades and its paper account' do
      run = Backtest::Run.create!(Backtest::RunValidator.call(run_payload))
      execute_run!(run)
      account_id = run.account_id

      delete "/api/backtest_runs/#{run.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Backtest::Run.exists?(run.id)).to be(false)
      expect(Backtest::Trade.where(backtest_run_id: run.id)).to be_empty
      expect(Account.exists?(account_id: account_id)).to be(false)
      expect(PaperExchange::PaperOrder.where(account_id: account_id)).to be_empty
    end
  end
end
