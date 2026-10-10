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

    # P0-1 fix: the accounting model now posts realized PnL via the
    # REALIZED_PNL ledger stream (not from TRADE debits/credits). The
    # realized PnL is the trading PnL: (sell_price - buy_price) * qty.
    # Fees are posted separately as FEE entries and reduce available_balance
    # (and thus equity), but do NOT reduce realized_pnl.
    gross_pnl = (sell_trade.price - buy_trade.price) * buy_trade.quantity

    # Equity = margin + realized_pnl - fees (no open positions => no unrealized)
    # realized_pnl is the gross trading PnL; fees reduce equity via available_balance.
    expect(account.realized_pnl).to be_within(1.0).of(gross_pnl.to_f)
    expect(account.unrealized_pnl).to be_within(1.0).of(0.0)
    # Equity should be margin + realized_pnl - total_fees
    total_fees = buy_trade.total_charges.to_f + sell_trade.total_charges.to_f
    expect(account.current_equity).to be_within(1.0).of(account.margin.to_f + gross_pnl.to_f - total_fees)

    # P0-1: ledger entries now include TRADE + MARGIN_LOCKED/MARGIN_UNLOCKED +
    # REALIZED_PNL + FEE (vs the old 2 TRADE entries).
    expect(LedgerEntry.where(account_id: account_id).count).to be >= 2
  end
end
