require 'rails_helper'

# P1-1 regression: the max-drawdown gate must detect drawdowns from a
# PEAK, not just from the initial margin. An account that grows from
# 100k to 200k and then falls to 150k has a 25% drawdown from peak —
# the old formula returned 0% because 150k > 100k (initial margin).
RSpec.describe 'P1-1: Max drawdown from peak', type: :integration do
  let(:account_id) { 'ACC-DD-PEAK' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }

  before { create(:account, account_id: account_id, margin: 100_000.0) }

  it 'tracks the equity high-water mark and rejects orders that breach the drawdown limit from peak' do
    # Grow the account: buy at 100, mark up to 200 (100% gain → equity ~200k)
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'BTCUSDT', bid: 100.0, ask: 100.0, ltp: 100.0, timestamp: Time.current
    ))
    exchange.submit_order(
      account_id: account_id, symbol: 'BTCUSDT', side: 'buy',
      quantity: 100, order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
      leverage: 1, margin_type: 'cross', execution_price: 100.0
    )

    # Mark price doubles to 200 → unrealized PnL = 100 * (200-100) = 10,000
    MarketData::MarkPriceStore.set('BTCUSDT', 200.0)
    summary = Projections::PortfolioProjection.summary(account_id)

    # The high-water mark should now be above the initial 100k
    account = Account.find_by!(account_id: account_id)
    expect(account.max_equity_achieved.to_f).to be > 100_000.0

    # Now simulate a drawdown: mark price drops to 50 (well below entry)
    # Unrealized PnL = 100 * (50-100) = -5,000
    # But to trigger the 20% drawdown gate we need a larger drop.
    # Close the position at a profit first to reset, then re-open and crash.
    exchange.submit_order(
      account_id: account_id, symbol: 'BTCUSDT', side: 'sell',
      quantity: 100, order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
      leverage: 1, margin_type: 'cross', execution_price: 200.0, reduce_only: true
    )

    # Account should now have ~200k equity (100k margin + ~100k realized gain minus fees)
    # Re-open at 200 and crash to 100 — that's a ~50% drawdown from peak.
    exchange.submit_order(
      account_id: account_id, symbol: 'BTCUSDT', side: 'buy',
      quantity: 100, order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
      leverage: 1, margin_type: 'cross', execution_price: 200.0
    )

    # Update the HWM by reading the summary at the high point
    Projections::PortfolioProjection.summary(account_id)
    account.reload
    peak = account.max_equity_achieved.to_f

    # Now crash the price to 100 → massive unrealized loss
    MarketData::MarkPriceStore.set('BTCUSDT', 100.0)

    # The drawdown validator should now see a real drawdown from peak
    validator = Risk::MaxDrawdownValidator.new
    signal = Strategy::Signal.new(
      account_id: account_id, symbol: 'BTCUSDT', side: 'buy',
      quantity: 1, order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
      ltp: 100.0, context: {}
    )
    result = validator.evaluate(account_id, signal)

    # With a ~50% drawdown from peak and a 20% threshold, this should reject
    expect(result).to eq(:MAX_DD_REJECTED)
  end
end
