require 'rails_helper'

# A cash-settled option needs the underlying's price to have a settlement value.
# Without it the settlement waits. It never settles on the option's own premium,
# which would book a false loss on an in-the-money option.
RSpec.describe OptionExpiryJob, 'settlement needs the underlying price', type: :job do
  let(:account_id) { 'ACC-EXPIRY-UNDERLYING' }
  let!(:account) { create(:account, account_id: account_id, margin: 100_000.0) }
  let(:now) { Time.utc(2026, 11, 3, 10, 0) }
  let!(:position) do
    create(:paper_position, account_id: account_id, symbol: 'NIFTY26000CE281126', side: :long, quantity: 50,
      avg_price: 120.0, current_price: 120.0, instrument_type: 'OPTIDX', option_type: 'CE',
      strike_price: 24_000.0, expiry_date: Date.new(2026, 11, 2))
  end

  before { MarketData::MarkPriceStore.clear }

  it 'defers settlement when the underlying index price is unknown, leaving the position open' do
    described_class.perform_now(now: now)

    expect(position.reload.quantity.to_f).to eq(50.0)
    expect(RiskEvent.where(event_type: 'OPTION_SETTLEMENT_DEFERRED').count).to eq(1)
  end

  it 'does not use the option premium as the underlying price' do
    # With the premium (120) standing in for the index, a 24,000 call would settle
    # at zero. The deferral must not be replaced by that false result.
    described_class.perform_now(now: now)

    expect(position.reload.quantity.to_f).to eq(50.0)
    expect(Ledger::Ledger.compute_realized_pnl(account_id)).to eq(0)
  end

  it 'settles at intrinsic value once the underlying price is known' do
    MarketData::MarkPriceStore.set('NIFTY', 24_500.0)

    described_class.perform_now(now: now)

    expect(position.reload.quantity.to_f).to eq(0.0)
    # Intrinsic value 500 against an entry premium of 120, on 50 units: +19,000.
    expect(Ledger::Ledger.compute_realized_pnl(account_id)).to be_within(1e-6).of(19_000.0)
  end
end
