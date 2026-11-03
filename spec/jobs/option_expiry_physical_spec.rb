require 'rails_helper'

# Stock options settle by delivery. They are never cash-settled here, and each
# such position gets one risk event asking for it to be exited.
RSpec.describe OptionExpiryJob, 'physically settled options', type: :job do
  let(:account_id) { 'ACC-PHYS' }
  let!(:account) { create(:account, account_id: account_id, margin: 100_000.0) }
  let(:expiry) { Date.new(2026, 11, 2) }
  let!(:position) do
    create(:paper_position, account_id: account_id, symbol: 'RELIANCE', side: :long, quantity: 2,
      avg_price: 50.0, current_price: 50.0, instrument_type: 'OPTSTK', option_type: 'CE',
      strike_price: 2500.0, expiry_date: expiry)
  end
  let(:now) { Time.utc(2026, 11, 3, 10, 0) }

  it 'leaves a stock option position open rather than cash-settling it' do
    described_class.perform_now(now: now)

    expect(position.reload.quantity.to_f).to eq(2.0)
  end

  it 'records one risk event for the position across repeated runs' do
    3.times { described_class.perform_now(now: now) }

    expect(RiskEvent.where(event_type: 'PHYSICAL_SETTLEMENT_REQUIRES_EXIT').count).to eq(1)
  end
end
