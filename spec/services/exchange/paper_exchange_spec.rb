require 'rails_helper'

RSpec.describe Exchange::PaperExchange, type: :service do
  let(:account_id) { 'ACC-TEST' }
  let(:exchange) { described_class.new(account_id: account_id) }

  before do
    create(:account, account_id: account_id)
  end

  describe '#submit_order' do
    let(:valid_attrs) do
      {
        account_id: account_id,
        symbol: 'RELIANCE',
        side: 'buy',
        quantity: 10,
        order_kind: 'market',
        instrument_type: 'EQUITY',
        price: nil
      }
    end

    before do
      exchange.market_event(MarketData::MarketEvent.new(
        symbol: 'RELIANCE',
        bid: 100,
        ask: 101,
        ltp: 100.5,
        timestamp: Time.current
      ))
    end

    it 'creates a paper order and returns result' do
      expect { exchange.submit_order(valid_attrs) }.to change(PaperExchange::PaperOrder, :count).by(1)
      order = PaperExchange::PaperOrder.last
      expect(order.status).to eq('filled')
    end

    context 'with invalid order' do
      let(:invalid_attrs) { valid_attrs.merge(side: 'invalid_side') }
      it 'raises and rejects order' do
        expect { exchange.submit_order(invalid_attrs) }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#submit_order with a crypto perpetual (no live feed of its own)' do
    let(:crypto_attrs) do
      {
        account_id: account_id,
        symbol: 'BTCUSDT',
        side: 'buy',
        quantity: 0.01,
        order_kind: 'market',
        instrument_type: Exchange::CryptoInstrumentCatalog::PERPETUAL,
        leverage: 10,
        margin_type: 'cross',
        execution_price: 65_000.0
      }
    end

    it 'fills using the agent-supplied execution_price instead of the equity stub' do
      order = exchange.submit_order(crypto_attrs)
      expect(order.status).to eq('filled')

      trade = PaperExchange::PaperTrade.find_by(paper_order_id: order.id)
      expect(trade.price.to_f).to be_within(1.0).of(65_000.0) # allows for the (tiny) slippage model
    end

    it 'locks leveraged initial margin, not the full notional' do
      exchange.submit_order(crypto_attrs)
      account = Account.find_by!(account_id: account_id)
      position = PaperExchange::PaperPosition.find_by!(account_id: account_id, symbol: 'BTCUSDT')

      expect(position.leverage).to eq(10)
      expect(position.liquidation_price).to be < position.avg_price
      expect(account.locked_margin.to_f).to be_within(0.5).of(65.0) # ~ (0.01 * 65000) / 10
    end

    context 'with a client_order_id' do
      let(:idempotent_attrs) { crypto_attrs.merge(client_order_id: 'agent-uuid-1') }

      it 'is idempotent: a repeated submission returns the original order without double-filling' do
        first = exchange.submit_order(idempotent_attrs)

        expect {
          second = exchange.submit_order(idempotent_attrs)
          expect(second.id).to eq(first.id)
        }.not_to change(PaperExchange::PaperTrade, :count)
      end

      it 'allows a different client_order_id to submit a genuinely new order' do
        first = exchange.submit_order(idempotent_attrs)
        second = exchange.submit_order(idempotent_attrs.merge(client_order_id: 'agent-uuid-2'))

        expect(second.id).not_to eq(first.id)
      end
    end
  end

  describe '#cancel_order' do
    let(:order) { create(:paper_order, account_id: account_id, status: :open) }
    it 'cancels the order' do
      exchange.cancel_order(order.id)
      expect(order.reload.status).to eq('cancelled')
    end
  end

  describe '#market_event' do
    let(:event) { MarketData::MarketEvent.new(symbol: 'NIFTY', bid: 100, ask: 101, ltp: 100.5, timestamp: Time.current) }
    it 'applies snapshot to order book' do
      expect { exchange.market_event(event) }.not_to raise_error
    end
  end
end
