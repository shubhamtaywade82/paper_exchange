require 'rails_helper'

# Cash equity is delivery-only: a sell that is not reduce_only may sell only the
# shares the account holds, less the shares its own open sell orders reserve.
RSpec.describe Exchange::PaperExchange, 'cash equity holdings', type: :service do
  let(:account_id) { 'ACC-EQ' }
  let(:exchange) { described_class.new(account_id: account_id) }

  def equity_order(side:, quantity:, **extra)
    { account_id: account_id, symbol: 'RELIANCE', side: side, quantity: quantity,
      order_kind: 'market', instrument_type: 'EQUITY' }.merge(extra)
  end

  before do
    create(:account, account_id: account_id)
    exchange.market_event(MarketData::MarketEvent.new(
      symbol: 'RELIANCE', bid: 100, ask: 101, ltp: 100.5, timestamp: Time.current
    ))
  end

  def buy!(quantity)
    exchange.submit_order(equity_order(side: 'buy', quantity: quantity))
  end

  describe 'a sell with no holding' do
    it 'is refused with the exchange rule' do
      expect { exchange.submit_order(equity_order(side: 'sell', quantity: 10)) }
        .to raise_error(described_class::InsufficientHoldingError, /0 held and unreserved; cash equity cannot be sold short/)
    end

    it 'persists no order' do
      expect {
        exchange.submit_order(equity_order(side: 'sell', quantity: 10)) rescue nil
      }.not_to change(PaperExchange::PaperOrder, :count)
    end

    it 'is refused when it would turn a long into a short' do
      buy!(10)

      expect { exchange.submit_order(equity_order(side: 'sell', quantity: 11)) }
        .to raise_error(described_class::InsufficientHoldingError, /10(\.0)? held and unreserved/)
      expect(PaperExchange::PaperPosition.find_by(account_id: account_id, symbol: 'RELIANCE').quantity).to eq(10)
    end
  end

  describe 'a sell within holdings' do
    it 'fills and leaves the position flat' do
      buy!(10)

      order = exchange.submit_order(equity_order(side: 'sell', quantity: 10))

      expect(order.status).to eq('filled')
      expect(PaperExchange::PaperPosition.find_by(account_id: account_id, symbol: 'RELIANCE').quantity).to eq(0)
    end

    it 'allows a partial exit and then refuses the remainder once it is gone' do
      buy!(10)
      exchange.submit_order(equity_order(side: 'sell', quantity: 4))

      expect { exchange.submit_order(equity_order(side: 'sell', quantity: 7)) }
        .to raise_error(described_class::InsufficientHoldingError, /6(\.0)? held and unreserved/)
      expect(exchange.submit_order(equity_order(side: 'sell', quantity: 6)).status).to eq('filled')
    end
  end

  describe 'shares reserved by an open sell order' do
    it 'cannot be sold a second time' do
      buy!(10)
      # A limit sell far above the bid rests unfilled, so its 10 shares stay reserved.
      resting = exchange.submit_order(equity_order(side: 'sell', quantity: 10, order_kind: 'bounded', price: 200))
      expect(resting.status).to eq('open')

      expect { exchange.submit_order(equity_order(side: 'sell', quantity: 1)) }
        .to raise_error(described_class::InsufficientHoldingError, /0 held and unreserved/)
    end

    it 'is released when the resting order is cancelled' do
      buy!(10)
      resting = exchange.submit_order(equity_order(side: 'sell', quantity: 10, order_kind: 'bounded', price: 200))
      exchange.cancel_order(resting.id)

      expect(exchange.submit_order(equity_order(side: 'sell', quantity: 10)).status).to eq('filled')
    end
  end

  describe 'other instruments' do
    # Scope only: the crypto perpetual's own order path needs a USDT account,
    # which is outside this guard. The check itself is called directly.
    it 'does not apply to a crypto perpetual, which may be shorted' do
      attrs = { symbol: 'BTCUSDT', side: 'sell', quantity: 1, instrument_type: 'CRYPTO_PERPETUAL' }

      expect { exchange.send(:assert_equity_holdings!, attrs) }.not_to raise_error
    end

    it 'does not apply to a reduce_only equity sell, which is clamped to the position instead' do
      attrs = { symbol: 'RELIANCE', side: 'sell', quantity: 1, instrument_type: 'EQUITY', reduce_only: true }

      expect { exchange.send(:assert_equity_holdings!, attrs) }.not_to raise_error
    end
  end
end
