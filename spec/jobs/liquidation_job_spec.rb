require 'rails_helper'

RSpec.describe LiquidationJob, type: :job do
  let(:account) { create(:account, account_id: 'ACC-LIQ-JOB', margin: 100_000.0) }

  let!(:position) do
    create(:paper_position,
      account_id: account.account_id,
      symbol: 'BTCUSDT',
      side: :long,
      quantity: 1,
      avg_price: 60_000.0,
      current_price: 60_000.0,
      instrument_type: Exchange::CryptoInstrumentCatalog::PERPETUAL,
      leverage: 10,
      liquidation_price: 54_000.0,
      initial_margin: 6_000.0)
  end

  before do
    allow_any_instance_of(Exchange::OrderBook).to receive(:snapshot).and_return(
      { bid: 53_400.0, ask: 53_600.0, ltp: 53_500.0, depth: { bids: [ [ 53_400.0, 100 ] ], asks: [ [ 53_600.0, 100 ] ] } }
    )
  end

  it 'force-closes the position with an opposite-side market order' do
    described_class.perform_now(position.id, 53_500.0)

    position.reload
    expect(position.quantity.to_f).to eq(0.0)
  end

  it 'records a POSITION_LIQUIDATED risk event' do
    expect {
      described_class.perform_now(position.id, 53_500.0)
    }.to change { RiskEvent.where(event_type: 'POSITION_LIQUIDATED').count }.by(1)

    event = RiskEvent.where(event_type: 'POSITION_LIQUIDATED').last
    expect(event.details['symbol']).to eq('BTCUSDT')
  end

  it 'does nothing if the position no longer breaches its liquidation price' do
    described_class.perform_now(position.id, 59_000.0)

    position.reload
    expect(position.quantity.to_f).to eq(1.0)
  end

  it 'does nothing if the position was already closed by the time it runs' do
    position.update_columns(quantity: 0)

    expect { described_class.perform_now(position.id, 53_500.0) }.not_to raise_error
  end

  it 'submits the close as reduce_only so it can never flip the position' do
    expect_any_instance_of(Exchange::PaperExchange).to receive(:submit_order)
      .with(hash_including(reduce_only: true, internal: true)).and_call_original

    described_class.perform_now(position.id, 53_500.0)
  end

  it 'returns quietly when a second run passes the re-check with a stale position' do
    described_class.perform_now(position.id, 53_500.0)
    # `position` still holds quantity 1 in memory, like a job that read the row before the first close committed.
    allow(::PaperExchange::PaperPosition).to receive(:find).with(position.id).and_return(position)

    expect { described_class.perform_now(position.id, 53_500.0) }.not_to raise_error

    expect(::PaperExchange::PaperPosition.find_by!(account_id: account.account_id, symbol: 'BTCUSDT').quantity.to_f).to eq(0.0)
    events = RiskEvent.where(account_id: account.account_id)
    expect(events.where(event_type: 'POSITION_LIQUIDATED').count).to eq(1)
    expect(events.where(event_type: 'LIQUIDATION_FAILED').count).to eq(0)
  end

  it 'records a LIQUIDATION_FAILED risk event and re-raises on failure' do
    allow(Exchange::PaperExchange).to receive(:new).and_raise(StandardError, 'boom')

    expect {
      described_class.perform_now(position.id, 53_500.0)
    }.to raise_error(StandardError, 'boom')

    expect(RiskEvent.where(event_type: 'LIQUIDATION_FAILED').count).to eq(1)
  end

  # M6 regression guard: a close order that never filled used to still emit
  # POSITION_LIQUIDATED while the position stayed open — and the enqueue had
  # already de-armed the position from the engine's watch cache.
  context 'when the close order never fills (audit M6)' do
    before do
      ActiveJob::Base.queue_adapter = :test
      # No order book for the symbol → matching returns [:rejected, "No book ..."]
      allow_any_instance_of(Exchange::OrderBook).to receive(:snapshot).and_return(nil)
    end

    it 'emits LIQUIDATION_FAILED (not POSITION_LIQUIDATED), keeps the position open, and re-arms the cache' do
      described_class.perform_now(position.id, 53_500.0)

      position.reload
      expect(position.quantity.to_f).to eq(1.0), 'position must still be open'
      expect(RiskEvent.where(event_type: 'LIQUIDATION_FAILED').count).to eq(1)
      expect(RiskEvent.where(event_type: 'POSITION_LIQUIDATED').count).to eq(0)

      failed = RiskEvent.find_by(event_type: 'LIQUIDATION_FAILED')
      expect(failed.details['order_status']).to eq('rejected')
      expect(failed.details['rejection_reason']).to include('No book')

      # Cache re-armed: the next mark-price push for the symbol re-enqueues
      # the liquidation for this still-open position.
      expect {
        Risk::LiquidationEngine.check_symbol!('BTCUSDT', 53_000.0)
      }.to have_enqueued_job(LiquidationJob).with(position.id, 53_000.0)
    end
  end
end
