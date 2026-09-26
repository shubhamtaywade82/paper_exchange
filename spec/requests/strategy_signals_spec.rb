require 'rails_helper'

# POST /api/strategy/signals — read-only pre-trade risk assessment.
# Asserts BOTH directions (allow/reject) and the absence of side
# effects: no order, no risk event, no ledger entry (audit M5 — the
# gate decides only; rejection events are submit_order's job).
RSpec.describe 'Strategy signals API', type: :request do
  let(:api_key) { ENV.fetch('PAPER_EXCHANGE_API_KEY') }
  let(:headers) { { 'X-API-Key' => api_key, 'X-Account-Id' => 'ACC-SIGNAL' } }
  let(:account) { create(:account, account_id: 'ACC-SIGNAL', margin: 10_000.0, available_balance: 10_000.0) }

  before { account }

  def post_signal(extra = {})
    post '/api/strategy/signals', params: {
      signal: { symbol: 'RELIANCE', side: 'buy', quantity: 2, instrument_type: 'EQUITY', ltp: '2500' }
    }.deep_merge(extra), headers: headers
  end

  it 'allows a fundable signal and reports the per-check outcomes' do
    post_signal

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['decision']).to eq('allow')
    expect(body['rejections']).to eq([])
    expect(body['checks']).to all(eq('passed'))
    expect(body['signal']).to include('symbol' => 'RELIANCE', 'quantity' => 2.0, 'leverage' => 1)
  end

  it 'rejects a signal the margin gate would block, with the rejection vocabulary' do
    post_signal(signal: { quantity: 100 }) # 250k notional on a 10k account

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['decision']).to eq('reject')
    expect(body['rejections']).to include('MARGIN_REJECTED')
  end

  it 'applies the VIX gate from context' do
    post_signal(signal: { context: { vix: '25.0' } })

    body = JSON.parse(response.body)
    expect(body['decision']).to eq('reject')
    expect(body['rejections']).to include('VIX_REJECTED')
  end

  it 'is read-only: no order, no risk event, no ledger entry is created' do
    expect {
      post_signal
      post_signal(signal: { quantity: 100 })
    }.not_to change {
      [ PaperExchange::PaperOrder.count, RiskEvent.count, LedgerEntry.count ]
    }
  end

  it 'attaches the latest market-structure snapshot for the symbol' do
    post '/api/market_structure', params: { symbol: 'RELIANCE', trend: 'bullish', timeframe: '5m' }, headers: headers
    post_signal(timeframe: '5m')

    body = JSON.parse(response.body)
    expect(body['market_structure']).to include('symbol' => 'RELIANCE', 'trend' => 'bullish', 'timeframe' => '5m')
  end

  it 'attaches null market structure when the symbol has no snapshot' do
    post_signal

    expect(JSON.parse(response.body)['market_structure']).to be_nil
  end

  it 'rejects malformed signals with 422' do
    post '/api/strategy/signals', params: { signal: { side: 'buy', quantity: 1 } }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)

    post '/api/strategy/signals', params: { signal: { symbol: 'RELIANCE', side: 'short', quantity: 1 } }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)

    post '/api/strategy/signals', params: { signal: { symbol: 'RELIANCE', side: 'buy', quantity: 'many' } }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)

    post '/api/strategy/signals', params: { signal: { symbol: 'RELIANCE', side: 'buy', quantity: 1, instrument_type: 'MOON' } }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)

    post '/api/strategy/signals', params: { signal: { symbol: 'RELIANCE', side: 'buy', quantity: 1, context: { vix: 'high' } } }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'accepts bare root params like POST /api/orders' do
    post '/api/strategy/signals', params: { symbol: 'RELIANCE', side: 'buy', quantity: 2, ltp: '2500' }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['decision']).to eq('allow')
  end
end
