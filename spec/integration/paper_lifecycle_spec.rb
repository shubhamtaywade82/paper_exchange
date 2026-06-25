require 'rails_helper'

RSpec.describe 'PaperExchange closed lifecycle', type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }

  before { create(:account, account_id: account_id) }

  it 'buys then sells and produces correct accounting' do
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE',
      bid: 100.0,
      ask: 100.5,
      ltp: 100.25,
      timestamp: Time.current
    ))

    buy_order = exchange.submit_order(
      account_id: account_id,
      symbol: 'RELIANCE',
      side: 'buy',
      quantity: 10,
      order_kind: 'market',
      instrument_type: 'EQUITY'
    )
    expect(buy_order).to be_persisted
    expect(buy_order.status).to eq('filled')
    expect(buy_order.filled_quantity).to eq(10)

    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE',
      bid: 110.0,
      ask: 110.5,
      ltp: 110.25,
      timestamp: Time.current
    ))

    sell_order = exchange.submit_order(
      account_id: account_id,
      symbol: 'RELIANCE',
      side: 'sell',
      quantity: 10,
      order_kind: 'market',
      instrument_type: 'EQUITY'
    )
    expect(sell_order).to be_persisted
    expect(sell_order.status).to eq('filled')
    expect(sell_order.filled_quantity).to eq(10)

    buy_trade = PaperExchange::PaperTrade.find_by(paper_order_id: buy_order.id)
    sell_trade = PaperExchange::PaperTrade.find_by(paper_order_id: sell_order.id)
    expect(buy_trade).to be_present
    expect(sell_trade).to be_present

    # Position should be closed
    position = PaperExchange::PaperPosition.find_by(account_id: account_id, symbol: 'RELIANCE')
    expect(position).to be_nil.or have_attributes(quantity: 0)

    account = Account.find_by!(account_id: account_id)

    # realized PnL from trades = credits - debits on trades (fees already in charges)
    trade_debit = buy_trade.price * buy_trade.quantity + buy_trade.total_charges
    trade_credit = sell_trade.price * sell_trade.quantity - sell_trade.total_charges
    expected_realized = trade_credit - trade_debit

    # Account equity should equal starting margin + realized PnL (no open positions => no unrealized)
    expected_equity = account.margin + expected_realized
    expect(account.current_equity).to be_within(0.01).of(expected_equity)
    expect(account.realized_pnl).to be_within(0.01).of(expected_realized)
    expect(account.unrealized_pnl).to be_within(0.01).of(0.0)

    # Ledger entries count: one trade entry per filled order (2 total)
    expect(LedgerEntry.where(account_id: account_id).count).to eq(2)
  end
end
