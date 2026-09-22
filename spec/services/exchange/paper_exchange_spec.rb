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
      it 'raises OrderValidationError before any order is persisted' do
        expect {
          expect { exchange.submit_order(invalid_attrs) }.to raise_error(Exchange::OrderValidationError)
        }.not_to change(PaperExchange::PaperOrder, :count)
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

  describe '#submit_order with reduce_only' do
    let(:open_attrs) do
      {
        account_id: account_id, symbol: 'BTCUSDT', side: 'buy', quantity: 0.1, order_kind: 'market',
        instrument_type: Exchange::CryptoInstrumentCatalog::PERPETUAL, leverage: 5,
        margin_type: 'isolated', execution_price: 65_000.0
      }
    end
    let(:close_attrs) { open_attrs.merge(side: 'sell', reduce_only: true, execution_price: 66_000.0) }
    let(:account) { Account.find_by!(account_id: account_id) }
    let(:position) { PaperExchange::PaperPosition.find_by!(account_id: account_id, symbol: 'BTCUSDT') }

    before { exchange.submit_order(open_attrs) }

    it 'closes the position without needing any available balance' do
      account.update_columns(available_balance: 0)

      order = exchange.submit_order(close_attrs)

      expect(order.status).to eq('filled')
      expect(position.quantity.to_f).to eq(0.0)
      expect(account.reload.locked_margin.to_f).to eq(0.0)
      expect(account.available_balance.to_f).to be > 0
    end

    it 'clamps the quantity to the open position size' do
      order = exchange.submit_order(close_attrs.merge(quantity: 1))

      expect(order.quantity.to_f).to eq(0.1)
      expect(order.filled_quantity.to_f).to eq(0.1)
      expect(position.quantity.to_f).to eq(0.0)
    end

    it 'books fee and realized pnl like a normal close' do
      exchange.submit_order(close_attrs)

      expect(LedgerEntry.where(account_id: account_id, event_type: 'REALIZED_PNL').sum(:credit).to_f).to eq(100.0)
      expect(LedgerEntry.where(account_id: account_id, event_type: 'FEE').count).to eq(2)
    end

    it 'rejects an order on the same side as the position without persisting it' do
      expect {
        expect { exchange.submit_order(close_attrs.merge(side: 'buy')) }
          .to raise_error(Exchange::OrderValidationError, /reduce_only/)
      }.not_to change(PaperExchange::PaperOrder, :count)
    end

    it 'rejects an order when the position is already flat, leaving no open order' do
      exchange.submit_order(close_attrs)

      expect {
        expect { exchange.submit_order(close_attrs) }.to raise_error(Exchange::OrderValidationError, /reduce_only/)
      }.not_to change(PaperExchange::PaperOrder, :count)
      expect(PaperExchange::PaperOrder.where(account_id: account_id, status: :open)).to be_empty
    end

    # Simulates another writer (e.g. LiquidationJob) mutating the position
    # after the cheap pre-transaction clamp but before the fill.
    def after_pre_clamp(&other_writer)
      allow(exchange).to receive(:clamp_to_position).and_wrap_original do |original, *args|
        original.call(*args).tap(&other_writer)
      end
    end

    context 'when the position is closed by another writer between the pre-check and the fill' do
      before do
        after_pre_clamp { described_class.new(account_id: account_id).submit_order(close_attrs) }
      end

      it 'rejects the order instead of opening an opposite position' do
        expect { exchange.submit_order(close_attrs.merge(client_order_id: 'racer')) }
          .to raise_error(Exchange::OrderValidationError, /reduce_only.*position gone/)

        racer = PaperExchange::PaperOrder.find_by!(account_id: account_id, client_order_id: 'racer')
        expect(racer.status).to eq('rejected')
        expect(racer.locked_margin.to_f).to eq(0.0)
        expect(position.quantity.to_f).to eq(0.0)
        expect(PaperExchange::PaperTrade.where(paper_order: PaperExchange::PaperOrder.where(account_id: account_id)).count).to eq(2)
        expect(account.reload.locked_margin.to_f).to eq(0.0)
      end
    end

    context 'when the position shrinks between the pre-check and the fill' do
      before { after_pre_clamp { position.update_columns(quantity: 0.04) } }

      it 'clamps to the live quantity so the position ends exactly flat' do
        order = exchange.submit_order(close_attrs)

        expect(order.status).to eq('filled')
        expect(order.reload.quantity.to_f).to eq(0.04)
        expect(order.filled_quantity.to_f).to eq(0.04)
        expect(position.reload.quantity.to_f).to eq(0.0)
        expect(position.side).to eq('long')
      end
    end

    it 'returns the original order when a client_order_id is replayed' do
      first = exchange.submit_order(close_attrs.merge(client_order_id: 'close-1'))

      expect {
        expect(exchange.submit_order(close_attrs.merge(client_order_id: 'close-1')).id).to eq(first.id)
      }.not_to change(PaperExchange::PaperTrade, :count)
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
