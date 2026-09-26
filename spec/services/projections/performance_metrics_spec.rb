require 'rails_helper'

RSpec.describe Projections::PerformanceMetrics, type: :service do
  let(:account_id) { 'ACC-TEST' }

  before { create(:account, account_id: account_id, current_equity: 100_000.0) }

  it 'returns current drawdown' do
    metrics = described_class.for(account_id)
    expect(metrics[:max_drawdown]).to be_a(Numeric)
  end

  it 'returns performance snapshot' do
    metrics = described_class.for(account_id)
    expect(metrics).to have_key(:unrealized_pnl)
    expect(metrics).to have_key(:realized_pnl)
  end

  it 'computes real realized_pnl from closed trades (#16 regression guard)' do
    order = create(:paper_order, account_id: account_id, status: :filled)
    position = create(:paper_position,
      account_id: account_id, symbol: order.symbol,
      side: :long, quantity: 10, avg_price: 100.0,
      instrument_type: order.instrument_type,
      option_type: order.option_type, strike_price: order.strike_price,
      expiry_date: order.expiry_date)
    create(:paper_trade,
      paper_order: order, paper_position: position,
      side: 'sell', quantity: 10, price: 110.0, total_charges: 1.0)

    metrics = described_class.for(account_id)
    # (110 - 100) * 10 - 1 = 99
    expect(metrics[:realized_pnl]).to be_within(0.01).of(99.0)
  end
  # Audit S14/T3.9: an all-wins history must not serialize profit_factor as
  # null (JSON cannot carry Infinity) — it reports at the cap instead; and
  # the summary projection is computed once.
  describe 'profit_factor serialization (audit S14)' do
    it 'caps an all-wins history at PROFIT_FACTOR_CAP instead of Infinity' do
      order = create(:paper_order, account_id: account_id, status: :filled)
      position = create(:paper_position,
        account_id: account_id, symbol: order.symbol,
        side: :long, quantity: 10, avg_price: 100.0,
        instrument_type: order.instrument_type,
        option_type: order.option_type, strike_price: order.strike_price,
        expiry_date: order.expiry_date)
      create(:paper_trade,
        paper_order: order, paper_position: position,
        side: 'sell', quantity: 10, price: 110.0, total_charges: 1.0)

      metrics = described_class.for(account_id)

      expect(metrics[:profit_factor]).to eq(described_class::PROFIT_FACTOR_CAP)
      expect(metrics[:profit_factor].to_s).to eq('999.0') # JSON-safe
    end

    it 'computes the summary projection once per call' do
      expect(Projections::PortfolioProjection).to receive(:summary).with(account_id).once.and_call_original

      described_class.for(account_id)
    end
  end
end
