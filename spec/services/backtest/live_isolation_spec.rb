require 'rails_helper'

# Regression spec (isolation). Backtest accounts share tables with live
# accounts. Live recurring jobs used to query across all accounts, so a
# simulated resting order could be filled by a live tick, or expired by the
# order-TTL sweep. Every such query is now scoped to live accounts.
RSpec.describe 'Backtest accounts are invisible to live jobs', type: :service do
  let(:live_id) { 'ACC-LIVE-ISOLATION' }
  let(:sim_id) { 'backtest-isolation' }

  # One exchange instance per account, as in production: each instance owns its
  # in-process order book, so the book must be set on the instance that submits.
  let(:live_exchange) { Exchange::PaperExchange.new(account_id: live_id) }
  let(:sim_exchange) { Exchange::PaperExchange.new(account_id: sim_id) }

  before do
    create(:account, account_id: live_id, margin: 100_000.0)
    create(:account, account_id: sim_id, margin: 100_000.0, simulated: true)
    [ live_exchange, sim_exchange ].each do |exchange|
      exchange.market_event(MarketData::MarketEvent.new(symbol: 'RELIANCE', bid: 100.0, ask: 100.0, ltp: 100.0, timestamp: Time.current))
    end
  end

  def resting_buy(exchange, price: 99.0)
    exchange.submit_order(
      account_id: exchange.account_id, symbol: 'RELIANCE', side: 'buy', quantity: 1,
      order_kind: 'bounded', price: price, instrument_type: 'EQUITY'
    )
  end

  it 'lets the live matching worker fill a live order and never a simulated one' do
    live_order = resting_buy(live_exchange)
    sim_order = resting_buy(sim_exchange)

    Exchange::MatchingWorker.new.process_tick(
      MarketData::MarketEvent.new(symbol: 'RELIANCE', bid: 98.5, ask: 98.5, ltp: 98.5, timestamp: Time.current)
    )

    expect(live_order.reload.status).to eq('filled')
    expect(sim_order.reload.status).to eq('open')
  end

  it 'expires a stale live order but leaves a stale simulated order alone' do
    live_order = resting_buy(live_exchange)
    sim_order = resting_buy(sim_exchange)
    expect(live_order.status).to eq('open')
    [ live_order, sim_order ].each { |order| order.update_column(:placed_at, 3.hours.ago) }

    ExpireOrdersJob.perform_now

    expect(live_order.reload.status).to eq('expired')
    expect(sim_order.reload.status).to eq('open')
  end

  it 'scopes positions, orders and protections to live accounts' do
    PaperExchange::PaperPosition.create!(account_id: live_id, symbol: 'RELIANCE', side: 'long', quantity: 1, avg_price: 100)
    PaperExchange::PaperPosition.create!(account_id: sim_id, symbol: 'RELIANCE', side: 'long', quantity: 1, avg_price: 100)

    expect(PaperExchange::PaperPosition.live_accounts.pluck(:account_id)).to eq([ live_id ])
  end

  it 'marks a backtest run account as simulated, and live accounts as live' do
    dataset = create_dataset!([ [ 100, 101, 99, 100 ], [ 100, 101, 99, 100 ], [ 100, 101, 99, 100 ] ])
    run = create_run!(dataset, strategy: signal_replay)
    execute_run!(run)

    expect(Account.find_by!(account_id: run.account_id).simulated).to be(true)
    expect(Account.live.pluck(:account_id)).to include(live_id)
    expect(Account.live.pluck(:account_id)).not_to include(run.account_id)
  end
end
