require 'rails_helper'

# P0-1 regression: the non-crypto wallet/equity accounting model.
# Buying a cash-equity position must:
#   1. Debit available_balance by the full purchase cost.
#   2. Lock that cost as position initial_margin.
#   3. Keep equity correct (available + locked + unrealized ~= starting margin
#      when the mark price equals the entry price, minus fees).
# Previously the purchase cost was NOT debited from available_balance and
# the TRADE ledger debit was double-counted in the equity formula, producing
# a phantom drawdown that could reject valid subsequent trades.
RSpec.describe 'P0-1: Non-crypto wallet accounting', type: :integration do
  let(:account_id) { 'ACC-EQUITY-ACCOUNTING' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }

  before { create(:account, account_id: account_id, margin: 100_000.0) }

  it 'debits available_balance and locks full notional on an equity purchase' do
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE', bid: 100.0, ask: 100.0, ltp: 100.0, timestamp: Time.current
    ))

    exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy',
      quantity: 100, order_kind: 'market', instrument_type: 'EQUITY',
      execution_price: 100.0
    )

    account = Account.find_by!(account_id: account_id)
    position = PaperExchange::PaperPosition.find_by!(account_id: account_id, symbol: 'RELIANCE')

    # Full notional (100 shares * ₹100) = ₹10,000 is locked as position margin
    # Allow a small delta for slippage/fee rounding.
    expect(position.initial_margin.to_f).to be_within(5.0).of(10_000.0)
    # Available balance is reduced by the purchase cost + fees
    expect(account.available_balance.to_f).to be_within(50.0).of(90_000.0)
    # Locked margin includes the position's full notional
    expect(account.locked_margin.to_f).to be_within(5.0).of(10_000.0)
  end

  it 'keeps equity correct at the entry price (no phantom drawdown)' do
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE', bid: 100.0, ask: 100.0, ltp: 100.0, timestamp: Time.current
    ))

    exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy',
      quantity: 100, order_kind: 'market', instrument_type: 'EQUITY',
      execution_price: 100.0
    )

    summary = Projections::PortfolioProjection.summary(account_id)

    # equity = available + locked + unrealized (0, price unchanged) = ~100k minus fees
    # Fees (brokerage + STT + GST + SEBI + stamp + exchange) are a real cost
    # that reduces equity. Allow up to 50 for fee impact.
    expect(summary[:equity]).to be_within(50.0).of(100_000.0)
    # Drawdown from peak should be minimal (fees only, not the 80% phantom drawdown)
    expect(summary[:drawdown]).to be_within(0.5).of(0.0)
  end

  it 'releases margin and posts realized PnL on a closing sell' do
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE', bid: 100.0, ask: 100.0, ltp: 100.0, timestamp: Time.current
    ))
    exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'buy',
      quantity: 100, order_kind: 'market', instrument_type: 'EQUITY',
      execution_price: 100.0
    )

    # Price moves up to 110
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE', bid: 110.0, ask: 110.0, ltp: 110.0, timestamp: Time.current
    ))
    exchange.submit_order(
      account_id: account_id, symbol: 'RELIANCE', side: 'sell',
      quantity: 100, order_kind: 'market', instrument_type: 'EQUITY',
      execution_price: 110.0
    )

    account = Account.find_by!(account_id: account_id)
    position = PaperExchange::PaperPosition.find_by(account_id: account_id, symbol: 'RELIANCE')

    # Position is flat — all margin released
    expect(position.quantity.to_f).to eq(0.0)
    expect(account.locked_margin.to_f).to be_within(1.0).of(0.0)

    # Realized PnL = (110 - 100) * 100 = 10,000 minus fees on both trades
    # Fees reduce the realized PnL. With execution_price pinned at 100 and 110,
    # the realized gross is 1,000 (not 10,000 — that was a spec error: the
    # original spec assumed 100 shares at 100→110 = 1000 profit, not 10000).
    # The REALIZED_PNL ledger entry captures the actual close PnL.
    expect(account.realized_pnl.to_f).to be > 500.0
    expect(account.realized_pnl.to_f).to be <= 1_000.0

    # Equity = starting margin + realized PnL (no open positions)
    expect(account.current_equity.to_f).to be > 100_500.0
  end
end
