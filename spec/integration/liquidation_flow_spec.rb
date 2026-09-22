require 'rails_helper'

# B3 regression guard: LiquidationJob used to call submit_order to force-close
# a position, which would lock_margin! against an already-underwater account,
# raise InsufficientMarginError, mark the close order rejected, and re-enqueue
# itself on every mark-price tick — infinite loop, position never closed.
#
# The fix is the `internal: true` flag on submit_order, which skips the
# margin lock and the risk gate for closing orders. The position's own
# initial_margin is still released correctly by MarginEngine.sync_position!
# once the position goes flat.
RSpec.describe 'Liquidation flow (B3)', type: :integration do
  let(:account_id) { 'ACC-LIQ-INT' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }

  before do
    create(:account, account_id: account_id, margin: 10_000.0, currency: 'USD')
    ActiveJob::Base.queue_adapter = :test
  end

  it 'force-closes a leveraged position without needing fresh margin' do
    # Open a 10x long on BTCUSDT at $60k. Margin locked: $600.
    open = exchange.submit_order(
      account_id: account_id,
      symbol: 'BTCUSDT', side: 'buy', quantity: 0.1,
      order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
      leverage: 10, margin_type: 'cross',
      execution_price: 60_000.0,
      client_order_id: 'liq-test-open'
    )
    expect(open.status).to eq('filled')

    position = PaperExchange::PaperPosition.find_by!(account_id: account_id, symbol: 'BTCUSDT')
    expect(position.leverage).to eq(10)
    expect(position.liquidation_price).to be < 60_000.0

    # Drain available_balance to simulate the underwater state that broke
    # the old code path — liquidation should still succeed.
    account = Account.find_by!(account_id: account_id)
    account.update_columns(available_balance: 0.0)

    breach_price = position.liquidation_price.to_f - 1.0
    expect {
      exchange.submit_order(
        account_id: account_id,
        symbol: 'BTCUSDT', side: 'sell', quantity: position.quantity.to_f,
        order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
        option_type: nil, strike_price: nil, expiry_date: nil,
        leverage: 10, margin_type: 'cross',
        ltp: breach_price,
        context: { reason: 'LIQUIDATION' },
        internal: true,
        client_order_id: 'liq-test-close'
      )
    }.not_to raise_error

    position.reload
    expect(position.quantity.to_f).to eq(0.0), 'position must be flat after liquidation'
  end
end
