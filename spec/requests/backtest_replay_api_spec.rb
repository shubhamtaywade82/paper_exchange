require 'rails_helper'

# A bot drives a backtest over HTTP and nothing else. It reads each bar from
# /advance, decides, and places orders on the run's account. Orders execute at
# the next bar's open, the replay reports the fills, and the finished run keeps
# its trades, equity, metrics and verdict.
RSpec.describe 'Bot-driven backtest over the API', type: :request do
  let(:headers) { { 'X-API-Key' => ENV.fetch('PAPER_EXCHANGE_API_KEY') } }
  let(:ohlc) do
    [
      [ 100, 101, 99, 100 ],
      [ 100, 102, 99, 101 ],
      [ 101, 103, 100, 102 ],
      [ 102, 104, 101, 103 ],
      [ 103, 105, 102, 104 ]
    ]
  end
  let(:dataset) { create_dataset!(ohlc) }
  let(:run_json) do
    post '/api/backtest_runs', headers: headers, as: :json, params: {
      dataset_id: dataset.id, name: 'bot run', mode: 'external', initial_capital: 10_000,
      benchmarks: { min_trades: 1, beat_buy_and_hold: true },
      manifest: { strategy: 'alma_cross', version: '1.4.0', params: { fast: 9 } }
    }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)
  end
  let(:run_id) { run_json['id'] }
  let(:account) { headers.merge('X-Account-Id' => run_json['account_id']) }

  def advance!
    post "/api/backtest_runs/#{run_id}/advance", headers: headers
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  def place!(**attrs)
    post '/api/orders', params: attrs, headers: account, as: :json
    response
  end

  # The account API reports money as decimal strings, as it always has.
  def balance
    get '/api/account', headers: account
    JSON.parse(response.body).then { |body| [ body['available_balance'].to_f, body['positions_count'] ] }
  end

  it 'exposes the run account at the initial capital before any bar is processed' do
    run_json

    expect(balance).to eq([ 10_000.0, 0 ])
  end

  it 'queues a bot order, executes it at the next bar open, and reports the fill' do
    run_json
    place!(symbol: 'RELIANCE', side: 'buy', quantity: 10, order_type: 'market', instrument_type: 'EQUITY', stop_loss: 95)
    expect(response).to have_http_status(:accepted)
    expect(JSON.parse(response.body)).to include('status' => 'queued', 'side' => 'buy', 'quantity' => 10.0)

    entry = advance!

    expect(entry['bar']).to include('bar_at' => '2026-11-02T03:45:00Z', 'open' => 100.0)
    expect(entry['submitted'].sole).to include('status' => 'submitted', 'role' => 'entry')
    expect(entry['fills'].sole).to include('side' => 'buy', 'quantity' => 10.0, 'price' => 100.0)
    expect(entry['position']).to include('side' => 'long', 'quantity' => 10.0, 'avg_price' => 100.0)
    expect(entry['finished']).to be(false)
  end

  it 'refuses fill prices from the bot, and entries without a protective stop' do
    run_json

    place!(symbol: 'RELIANCE', side: 'buy', quantity: 10, instrument_type: 'EQUITY', stop_loss: 95, execution_price: 99)
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to include('execution_price is not accepted')

    place!(symbol: 'RELIANCE', side: 'buy', quantity: 10, instrument_type: 'EQUITY')
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to include('stop_loss_required')
  end

  it 'refuses an order for another instrument than the run trades' do
    run_json

    place!(symbol: 'NIFTY', side: 'buy', quantity: 10, instrument_type: 'EQUITY', stop_loss: 95)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to include('symbol must be RELIANCE')
  end

  it 'lets a bot exit at the next open and finishes the run itself on the last bar' do
    run_json
    place!(symbol: 'RELIANCE', side: 'buy', quantity: 10, instrument_type: 'EQUITY', stop_loss: 95)
    advance!                       # bar 0: entry fills at 100
    advance!                       # bar 1: nothing to do

    held = advance!                # bar 2: the bot sees a long and decides to exit
    expect(held['position']).to include('quantity' => 10.0)
    place!(symbol: 'RELIANCE', side: 'sell', quantity: 10, order_type: 'market', instrument_type: 'EQUITY', reduce_only: true)
    expect(response).to have_http_status(:accepted)

    exit_step = advance!          # bar 3: the exit fills at 102, the bar's open
    expect(exit_step['fills'].sole).to include('side' => 'sell', 'price' => 102.0)
    expect(exit_step['position']).to be_nil

    last = advance!               # bar 4 is the last bar
    expect(last['finished']).to be(true)
    expect(last['verdict']).to include('passed' => false)
    expect(last['verdict']['checks'].map { |c| [ c['check'], c['passed'] ] }).to include([ 'min_trades', true ], [ 'beat_buy_and_hold', false ])

    post "/api/backtest_runs/#{run_id}/advance", headers: headers
    expect(response).to have_http_status(:conflict)
  end

  it 'stores the finished run: manifest, trades with exit reason, equity and verdict' do
    run_json
    place!(symbol: 'RELIANCE', side: 'buy', quantity: 10, instrument_type: 'EQUITY', stop_loss: 95)
    5.times { advance! }

    get "/api/backtest_runs/#{run_id}", headers: headers
    body = JSON.parse(response.body)
    expect(body).to include('status' => 'completed', 'mode' => 'external', 'bars_processed' => 5)
    expect(body['manifest']).to include('strategy' => 'alma_cross', 'version' => '1.4.0')
    expect(body['benchmarks']).to include('min_trades' => '1.0', 'beat_buy_and_hold' => true)

    get "/api/backtest_runs/#{run_id}/trades", headers: headers
    expect(JSON.parse(response.body)['data']).to be_empty   # the long was never closed: it is open at the end

    get "/api/backtest_runs/#{run_id}/equity", headers: headers
    expect(JSON.parse(response.body)['data'].size).to eq(5)

    get "/api/backtest_runs/#{run_id}/intents", headers: headers
    # The entry was submitted. Its protective stop was still resting at end of data, so it was withdrawn.
    intents = JSON.parse(response.body)['data']
    expect(intents.map { |i| i['status'] }).to contain_exactly('submitted', 'cancelled')
    expect(intents.find { |i| i['status'] == 'submitted' }).to include('role' => 'entry', 'source' => 'api')
    expect(body['diagnostics']).to include('open_position_at_end' => include('side' => 'long', 'quantity' => '10.0'))
  end

  it 'returns only bars the replay has reached, so a bot cannot read the future' do
    run_json
    advance!
    advance!

    get "/api/backtest_runs/#{run_id}/history", headers: headers

    data = JSON.parse(response.body)['data']
    expect(data.map { |bar| bar['bar_at'] }).to eq([ '2026-11-02T03:45:00Z', '2026-11-02T03:50:00Z' ])
  end

  it 'does not let live market-data writes move a replay account' do
    run_json

    post '/api/mark_prices', params: { prices: { RELIANCE: 1 } }, headers: account, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to include('moves its own prices')
  end

  it 'refuses stop_loss on a live account, which uses protections' do
    post '/api/orders', headers: headers.merge('X-Account-Id' => 'ACC-LIVE-NO-STOPS'), as: :json, params: {
      symbol: 'RELIANCE', side: 'buy', quantity: 1, order_type: 'market', instrument_type: 'EQUITY', stop_loss: 95
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to include('/api/positions/:id/protections')
  end

  it 'refuses the engine path for an external run, and resets it to an empty account' do
    run_json
    place!(symbol: 'RELIANCE', side: 'buy', quantity: 10, instrument_type: 'EQUITY', stop_loss: 95)
    advance!

    post "/api/backtest_runs/#{run_id}/execute", headers: headers
    expect(response).to have_http_status(:conflict)

    post "/api/backtest_runs/#{run_id}/reset", headers: headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include('status' => 'pending', 'bars_processed' => 0)

    expect(balance).to eq([ 10_000.0, 0 ])
    get "/api/backtest_runs/#{run_id}/intents", headers: headers
    expect(JSON.parse(response.body)['data']).to be_empty
  end
end
