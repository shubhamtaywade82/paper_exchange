require 'rails_helper'

# P1-1 regression: the max-drawdown gate must detect drawdowns from a
# PEAK, not just from the initial margin. An account that grows from
# 100k to 200k and then falls to 150k has a 25% drawdown from peak —
# the old formula returned 0% because 150k > 100k (initial margin).
RSpec.describe 'P1-1: Max drawdown from peak', type: :integration do
  let(:account_id) { 'ACC-DD-PEAK' }

  it 'rejects orders that breach the drawdown limit from the equity high-water mark' do
    # Start with 100k, set the HWM to 200k (simulating growth), then
    # drop available_balance to 150k (25% drawdown from 200k peak).
    create(:account, account_id: account_id, margin: 100_000.0, currency: 'USD')
    account = Account.find_by!(account_id: account_id)
    account.update_columns(
      available_balance: 150_000.0,
      max_equity_achieved: 200_000.0,
      current_equity: 150_000.0
    )

    # The drawdown from peak = (200k - 150k) / 200k = 25% > 20% threshold.
    validator = Risk::MaxDrawdownValidator.new
    signal = Strategy::Signal.new(
      account_id: account_id, symbol: 'BTCUSDT', side: 'buy',
      quantity: 1, order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
      ltp: 100.0, context: {}
    )
    expect(validator.evaluate(account_id, signal)).to eq(:MAX_DD_REJECTED)
  end

  it 'passes when the drawdown from peak is within the limit' do
    # HWM = 200k, current equity = 190k → 5% drawdown → passes.
    create(:account, account_id: account_id, margin: 100_000.0, currency: 'USD')
    account = Account.find_by!(account_id: account_id)
    account.update_columns(
      available_balance: 190_000.0,
      max_equity_achieved: 200_000.0,
      current_equity: 190_000.0
    )

    validator = Risk::MaxDrawdownValidator.new
    signal = Strategy::Signal.new(
      account_id: account_id, symbol: 'BTCUSDT', side: 'buy',
      quantity: 1, order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
      ltp: 100.0, context: {}
    )
    expect(validator.evaluate(account_id, signal)).to eq(:passed)
  end
end
