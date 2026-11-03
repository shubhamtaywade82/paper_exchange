require 'rails_helper'

# The ways the replay refuses, rejects, or fails work. Each test drives one of
# them through Backtest::Replay. Where the exchange itself must refuse an
# order, the refusal is stubbed at PaperExchange#submit_order, the boundary a
# real refusal crosses.
RSpec.describe Backtest::Replay, type: :service do
  let(:flat) { [ 100, 101, 99, 100 ] }

  def external_run!(ohlc, dataset_options: {}, **overrides)
    dataset = create_dataset!(ohlc, **dataset_options)
    attrs = { dataset_id: dataset.id, name: 'refusals', mode: 'external', initial_capital: 10_000 }.merge(overrides)
    Backtest::RunManager.create!(Backtest::RunValidator.call(attrs))
  end

  def place_order(run, **attrs)
    described_class.new(run).queue_api_order!({ symbol: 'RELIANCE', instrument_type: 'EQUITY' }.merge(attrs))
  end

  # Orders matching `matching` are refused with the order `refusal` builds, as a
  # real rejection would arrive. Other orders go to the real exchange.
  def refuse_orders(matching:, refusal:)
    allow_any_instance_of(Exchange::PaperExchange).to receive(:submit_order).and_wrap_original do |original, attrs|
      matching.call(attrs) ? refusal.call(attrs) : original.call(attrs)
    end
  end

  def rejected_order(attrs, reason)
    ::PaperExchange::PaperOrder.create!(
      account_id: attrs[:account_id], symbol: attrs[:symbol], instrument_type: attrs[:instrument_type],
      side: attrs[:side], quantity: attrs[:quantity], order_kind: attrs[:order_kind],
      trigger_price: attrs[:trigger_price], price: attrs[:price],
      status: :rejected, rejection_reason: reason
    )
  end

  describe 'a protective stop the exchange refuses (fail closed)' do
    before do
      refuse_orders(
        matching: ->(attrs) { attrs[:reduce_only] && attrs[:order_kind] == 'stop_loss' },
        refusal: ->(attrs) { rejected_order(attrs, 'refused by the exchange') }
      )
    end

    it 'fails the run rather than continuing with an unprotected position' do
      run = external_run!([ flat, flat, flat ])
      place_order(run, side: 'buy', quantity: 10, order_type: 'market', stop_loss: 95)

      expect { described_class.new(run).advance! }
        .to raise_error(Backtest::OrderManager::ExecutionError,
          /stop order could not be placed \(exchange_rejected\): refused by the exchange/)

      run.reload
      expect(run.status).to eq('failed')
      expect(run.failure_reason).to include('stop order could not be placed')
    end

    it 'then refuses further bars, because a failed run accepts none' do
      run = external_run!([ flat, flat, flat ])
      place_order(run, side: 'buy', quantity: 10, order_type: 'market', stop_loss: 95)
      replay = described_class.new(run)
      expect { replay.advance! }.to raise_error(Backtest::OrderManager::ExecutionError)

      expect { replay.advance! }.to raise_error(described_class::Conflict, /run is failed/)
    end
  end

  describe 'orders the exchange refuses (rejected, not fatal)' do
    it 'rejects an entry the exchange refuses, records the reason, and keeps the run going' do
      run = external_run!([ flat, flat ])
      place_order(run, side: 'buy', quantity: 10, order_type: 'market', stop_loss: 95)
      refuse_orders(
        matching: ->(attrs) { !attrs[:reduce_only] },
        refusal: ->(attrs) { rejected_order(attrs, 'exchange refused the entry') }
      )

      step = described_class.new(run).advance!

      expect(step.submitted.sole).to have_attributes(
        status: 'rejected', rejection_reason: 'exchange_rejected: exchange refused the entry'
      )
      run.reload
      expect(run.diagnostics['rejected_intents']).to eq('exchange_rejected' => 1)
      expect(run.status).to eq('running')
    end

    it 'rejects an entry when the exchange raises a validation error' do
      run = external_run!([ flat, flat ])
      place_order(run, side: 'buy', quantity: 10, order_type: 'market', stop_loss: 95)
      allow_any_instance_of(Exchange::PaperExchange).to receive(:submit_order)
        .and_raise(Exchange::OrderValidationError, 'the exchange rejected the order shape')

      step = described_class.new(run).advance!

      expect(step.submitted.sole).to have_attributes(
        status: 'rejected', rejection_reason: 'order_invalid: the exchange rejected the order shape'
      )
      expect(run.reload.diagnostics['rejected_intents']).to eq('order_invalid' => 1)
    end
  end

  describe 'orders the replay rejects at execution' do
    it 'rejects a reduce-only order on the side that would open a position' do
      run = external_run!([ flat, flat, flat ])
      place_order(run, side: 'buy', quantity: 10, order_type: 'market', stop_loss: 95)
      replay = described_class.new(run)
      replay.advance! # the long fills at bar 0
      place_order(run, side: 'buy', quantity: 10, reduce_only: true) # a buy against a long opens, it does not close

      step = replay.advance!

      expect(step.submitted.sole).to have_attributes(status: 'rejected', rejection_reason: 'reduce_only_wrong_side')
      expect(step.position.quantity).to eq(10)
    end

    it 'rejects a take-profit on the wrong side of the entry price' do
      run = external_run!([ flat, flat ])
      place_order(run, side: 'buy', quantity: 10, order_type: 'market', stop_loss: 95, take_profit: 90)

      step = described_class.new(run).advance!

      expect(step.submitted.sole).to have_attributes(status: 'rejected', rejection_reason: 'take_profit_wrong_side')
    end
  end

  describe 'orders checked against the run definition at placement' do
    it 'refuses an instrument other than the one the run trades' do
      run = external_run!([ flat, flat ])

      expect { place_order(run, instrument_type: 'CRYPTO_PERPETUAL', side: 'buy', quantity: 10, order_type: 'market', stop_loss: 95) }
        .to raise_error(described_class::Invalid, 'instrument_type must be EQUITY on this run')
    end

    it 'refuses a leverage outside 1 to 100 on a perpetual' do
      run = external_run!([ flat, flat ], dataset_options: { symbol: 'BTCUSDT', instrument_type: 'CRYPTO_PERPETUAL', currency: 'USDT' }, leverage: 10)

      expect {
        place_order(run, symbol: 'BTCUSDT', instrument_type: 'CRYPTO_PERPETUAL', side: 'buy', quantity: 1,
          order_type: 'market', stop_loss: 95, leverage: 500)
      }.to raise_error(described_class::Invalid, 'leverage must be an integer between 1 and 100')
    end
  end
end
