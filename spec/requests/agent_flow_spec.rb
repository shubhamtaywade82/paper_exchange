require 'rails_helper'

# #17: the calls a trading agent makes, in order, over HTTP. The agent repository
# is not reachable from this one, so this covers the agent-facing contract from
# the broker side: order entry with a strategy key, position attribution, wallet
# consistency, idempotent funding, the close, and the fills stream.
RSpec.describe 'Agent API flow (#17)', type: :request do
  let(:account_id) { 'ACC-AGENT-E2E' }
  let(:headers) { { 'X-API-Key' => ENV.fetch('PAPER_EXCHANGE_API_KEY'), 'X-Account-Id' => account_id } }

  before do
    create(:account, account_id: account_id, margin: 100_000.0, currency: 'USDT')
    ActiveJob::Base.queue_adapter = :test
    allow(ActionCable.server).to receive(:broadcast).and_call_original
  end

  it 'opens a strategy-tagged perp, funds it once per settlement, closes it, and keeps the wallet consistent' do
    # 1. Open a 10x long (0.1 BTC at 60000 locks 600) with a strategy key.
    post '/api/v1/orders', params: {
      symbol: 'BTCUSDT', side: 'buy', quantity: '0.1', order_type: 'market',
      instrument_type: 'CRYPTO_PERPETUAL', leverage: 10, margin_type: 'cross',
      execution_price: '60000', client_order_id: 'agent-open',
      context: { strategy_key: 'sma_cross' }
    }, headers: headers
    expect(response).to have_http_status(:created)
    expect(PaperExchange::PaperOrder.find_by!(account_id: account_id, client_order_id: 'agent-open').status).to eq('filled')

    # 2. The position records the strategy that opened it (#19).
    get '/api/v1/positions', headers: headers
    expect(response).to have_http_status(:ok)
    position = JSON.parse(response.body).find { |p| p['symbol'] == 'BTCUSDT' }
    expect(position).to be_present
    expect(position['metadata']).to eq('strategy_key' => 'sma_cross')

    # 3. The wallet agrees with the ledger-backed locked margin (#11).
    get '/api/v1/account', headers: headers
    account = JSON.parse(response.body)
    expect(account['locked_margin'].to_f).to eq(600.0)
    expect(account['wallet']['locked'].to_f).to eq(account['locked_margin'].to_f)

    # 4. The bot retries the same settlement. It is charged once (#60).
    funding = { symbol: 'BTCUSDT', funding_rate: '0.0001', funding_time: '2026-09-20T08:00:00Z', sync: 'true' }
    2.times { post '/api/v1/funding_events', params: funding, headers: headers }
    expect(response).to have_http_status(:accepted)
    expect(FundingPayment.where(account_id: account_id).count).to eq(1)

    # 5. The next settlement is charged, not skipped (#60).
    post '/api/v1/funding_events', params: funding.merge(funding_time: '2026-09-20T16:00:00Z'), headers: headers
    expect(FundingPayment.where(account_id: account_id).count).to eq(2)

    # 6. Close the position. The fill is broadcast on the fills stream (#8)
    #    and the closing trade is linked to the position (#5).
    expect(ActionCable.server).to receive(:broadcast)
      .with("fills:#{account_id}", hash_including(symbol: 'BTCUSDT', side: 'sell'))
      .and_call_original

    post '/api/v1/orders', params: {
      symbol: 'BTCUSDT', side: 'sell', quantity: '0.1', order_type: 'market',
      instrument_type: 'CRYPTO_PERPETUAL', leverage: 10, margin_type: 'cross',
      execution_price: '61000', client_order_id: 'agent-close'
    }, headers: headers
    expect(response).to have_http_status(:created)

    closing_order = PaperExchange::PaperOrder.find_by!(account_id: account_id, client_order_id: 'agent-close')
    closing_trade = PaperExchange::PaperTrade.find_by!(paper_order_id: closing_order.id)
    expect(closing_trade.paper_position_id).to be_present

    # 7. After the close the wallet still agrees with the ledger (#11).
    get '/api/v1/account', headers: headers
    account = JSON.parse(response.body)
    expect(account['wallet']['locked'].to_f).to eq(account['locked_margin'].to_f)
  end
end
