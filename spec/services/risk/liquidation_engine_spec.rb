require 'rails_helper'

RSpec.describe Risk::LiquidationEngine, type: :service do
  before do
    described_class.reset_cache!
    ActiveJob::Base.queue_adapter = :test
  end

  after { described_class.clock = nil }

  let(:account) { create(:account, account_id: 'ACC-LIQ') }

  # #9 regression guards. A breached position used to leave the watch cache
  # on enqueue, so a LiquidationJob that failed left it unwatched until some
  # later refresh. It now stays watched, and re-enqueues once PENDING_TTL
  # passes if the database still shows it open.
  describe 'after enqueueing a breached position' do
    let(:now) { [ 0.0 ] }

    before { described_class.clock = -> { now.first } }

    it 're-enqueues a still-open position once the pending entry expires' do
      position = leveraged_position(side: :long, liquidation_price: 54_000.0)
      described_class.refresh_cache!

      expect {
        described_class.check_symbol!('BTCUSDT', 53_000.0)
      }.to have_enqueued_job(LiquidationJob).with(position.id, 53_000.0)

      now[0] += described_class::PENDING_TTL - 0.1
      expect {
        described_class.check_symbol!('BTCUSDT', 53_000.0)
      }.not_to have_enqueued_job(LiquidationJob)

      now[0] += 0.2
      expect {
        described_class.check_symbol!('BTCUSDT', 53_000.0)
      }.to have_enqueued_job(LiquidationJob).with(position.id, 53_000.0)
    end

    it 'keeps a breached position watched across a refresh while it is still open' do
      position = leveraged_position(side: :long, liquidation_price: 54_000.0)
      described_class.refresh_cache!
      described_class.check_symbol!('BTCUSDT', 53_000.0)

      described_class.refresh_cache!
      now[0] += described_class::PENDING_TTL + 1

      expect {
        described_class.check_symbol!('BTCUSDT', 53_000.0)
      }.to have_enqueued_job(LiquidationJob).with(position.id, 53_000.0)
    end

    it 'forgets pending enqueues on reset_cache!' do
      position = leveraged_position(side: :long, liquidation_price: 54_000.0)
      described_class.refresh_cache!
      described_class.check_symbol!('BTCUSDT', 53_000.0)

      described_class.reset_cache!
      described_class.refresh_cache!

      expect {
        described_class.check_symbol!('BTCUSDT', 53_000.0)
      }.to have_enqueued_job(LiquidationJob).with(position.id, 53_000.0)
    end
  end

  def leveraged_position(side:, liquidation_price:)
    create(:paper_position,
      account_id: account.account_id,
      symbol: 'BTCUSDT',
      side: side,
      quantity: 1,
      avg_price: 60_000.0,
      current_price: 60_000.0,
      leverage: 10,
      liquidation_price: liquidation_price)
  end

  describe '.refresh_cache!' do
    it 'ignores unleveraged positions even if a stray liquidation_price were ever set on one' do
      leveraged_position(side: :long, liquidation_price: 54_000.0)
      create(:paper_position, account_id: account.account_id, symbol: 'RELIANCE', side: :long, quantity: 10, avg_price: 2_500.0, leverage: 1)
      described_class.refresh_cache!

      expect {
        described_class.check_symbol!('RELIANCE', 1.0)
      }.not_to have_enqueued_job(LiquidationJob)
    end

    it 'picks up newly opened leveraged positions on the next refresh' do
      leveraged_position(side: :long, liquidation_price: 54_000.0)
      described_class.refresh_cache!

      expect {
        described_class.check_symbol!('BTCUSDT', 53_999.0)
      }.to have_enqueued_job(LiquidationJob)
    end
  end

  describe '.check_symbol!' do
    it 'enqueues LiquidationJob when a long position price is breached' do
      position = leveraged_position(side: :long, liquidation_price: 54_000.0)
      described_class.refresh_cache!

      expect {
        described_class.check_symbol!('BTCUSDT', 53_500.0)
      }.to have_enqueued_job(LiquidationJob).with(position.id, 53_500.0)
    end

    it 'enqueues LiquidationJob when a short position price is breached' do
      position = leveraged_position(side: :short, liquidation_price: 66_000.0)
      described_class.refresh_cache!

      expect {
        described_class.check_symbol!('BTCUSDT', 66_500.0)
      }.to have_enqueued_job(LiquidationJob).with(position.id, 66_500.0)
    end

    it 'does not enqueue anything while price stays within bounds' do
      leveraged_position(side: :long, liquidation_price: 54_000.0)
      described_class.refresh_cache!

      expect {
        described_class.check_symbol!('BTCUSDT', 59_000.0)
      }.not_to have_enqueued_job(LiquidationJob)
    end

    it 'does not enqueue the same breached position twice from a burst of ticks' do
      position = leveraged_position(side: :long, liquidation_price: 54_000.0)
      described_class.refresh_cache!

      described_class.check_symbol!('BTCUSDT', 53_000.0)
      expect {
        described_class.check_symbol!('BTCUSDT', 52_000.0)
      }.not_to have_enqueued_job(LiquidationJob)
    end

    it 'is a no-op for a symbol with no cached leveraged positions' do
      expect {
        described_class.check_symbol!('DOGEUSDT', 1.0)
      }.not_to have_enqueued_job(LiquidationJob)
    end
  end
end
