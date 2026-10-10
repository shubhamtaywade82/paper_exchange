require 'rails_helper'

# Architecture alignment (target architecture §4): MatchingWorker specs.
# The worker consumes market events from the Redis tick stream and fills
# open orders against the latest quotes — making PaperExchange independent
# of the trading bot staying alive.
RSpec.describe Exchange::MatchingWorker, type: :service do
  let(:account_id) { 'ACC-MATCH-WORKER' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }
  let(:worker) { described_class.new }

  before { create(:account, account_id: account_id, margin: 100_000.0) }

  describe '#process_tick' do
    it 'updates QuoteStore with the tick and fills a marketable open order' do
      # Create an open order manually (not via submit_order, which would
      # fill it immediately against the stub book).
      order = create(:paper_order,
        account_id: account_id,
        symbol: 'RELIANCE',
        side: :buy,
        quantity: 10,
        order_kind: :market,
        instrument_type: 'EQUITY',
        status: :open,
        placed_at: Time.current,
        locked_margin: 1_000.0
      )

      # Push a tick — the worker should fill the open order.
      event = MarketData::MarketEvent.new(
        symbol: 'RELIANCE', bid: 100.0, ask: 100.0, ltp: 100.0, timestamp: Time.current
      )
      worker.process_tick(event)

      order.reload
      expect(order.status).to eq('filled')
    end

    it 'does not fill a limit order when the book does not cross the limit' do
      order = create(:paper_order,
        account_id: account_id,
        symbol: 'RELIANCE',
        side: :buy,
        quantity: 10,
        order_kind: :bounded,
        instrument_type: 'EQUITY',
        status: :open,
        price: 90.0, # limit below the ask
        placed_at: Time.current,
        locked_margin: 1_000.0
      )

      event = MarketData::MarketEvent.new(
        symbol: 'RELIANCE', bid: 95.0, ask: 100.0, ltp: 97.5, timestamp: Time.current
      )
      worker.process_tick(event)

      order.reload
      expect(order.status).to eq('open') # not filled — limit not crossed
    end

    it 'fills a limit order when the book crosses the limit (with price improvement)' do
      order = create(:paper_order,
        account_id: account_id,
        symbol: 'RELIANCE',
        side: :buy,
        quantity: 10,
        order_kind: :bounded,
        instrument_type: 'EQUITY',
        status: :open,
        price: 105.0, # limit above the ask — marketable
        placed_at: Time.current,
        locked_margin: 1_000.0
      )

      event = MarketData::MarketEvent.new(
        symbol: 'RELIANCE', bid: 99.0, ask: 100.0, ltp: 99.5, timestamp: Time.current
      )
      worker.process_tick(event)

      order.reload
      expect(order.status).to eq('filled')
      trade = PaperExchange::PaperTrade.find_by(paper_order_id: order.id)
      # Price improvement: fill at ask (100), not at the limit (105)
      expect(trade.price.to_f).to be_within(1.0).of(100.0)
    end
  end
end
