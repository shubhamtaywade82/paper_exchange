require 'rails_helper'

# P0-2 regression: funding settlement must be ATOMIC with its idempotency
# record. If the ledger post fails AFTER the FundingPayment row is created,
# the payment must roll back so a retried job re-settles from scratch.
# Previously the payment was committed first, then the ledger posted —
# a crash in between left a "settled" payment with no wallet adjustment.
RSpec.describe 'P0-2: Funding settlement atomicity', type: :job do
  let(:account) { create(:account, account_id: 'ACC-FUND-ATOMIC', margin: 100_000.0) }

  let!(:position) do
    create(:paper_position,
      account_id: account.account_id,
      symbol: 'BTCUSDT',
      side: :long,
      quantity: 1,
      avg_price: 60_000.0,
      current_price: 60_000.0,
      instrument_type: Exchange::CryptoInstrumentCatalog::PERPETUAL,
      leverage: 1) # P0-2: 1x leverage should still settle funding
  end

  let(:funding_time) { Time.zone.parse('2026-10-10T08:00:00Z') }

  it 'settles funding for 1x leverage positions (not just leverage > 1)' do
    expect {
      FundingJob.perform_now('BTCUSDT', 0.0003, 60_000.0, funding_time)
    }.to change(FundingPayment, :count).by(1)
    .and change { LedgerEntry.where(event_type: 'FUNDING_FEE').count }.by(1)
  end

  it 'rolls back the payment when the ledger post fails (atomic settlement)' do
    # Simulate a ledger failure: inject a raise into MarginLedger.deduct_fee!
    # The payment row should roll back with the transaction.
    allow(Ledger::MarginLedger).to receive(:deduct_fee!)
      .and_raise(StandardError, 'simulated ledger failure')

    expect {
      FundingJob.perform_now('BTCUSDT', 0.0003, 60_000.0, funding_time)
    }.to raise_error(StandardError, /simulated ledger failure/)

    # P0-2: the payment must NOT exist — the transaction rolled back
    expect(FundingPayment.where(account_id: account.account_id).count).to eq(0)
    expect(LedgerEntry.where(account_id: account.account_id, event_type: 'FUNDING_FEE').count).to eq(0)

    # Retry the job — it should now succeed (no prior payment to dedup against)
    allow(Ledger::MarginLedger).to receive(:deduct_fee!).and_call_original
    expect {
      FundingJob.perform_now('BTCUSDT', 0.0003, 60_000.0, funding_time)
    }.to change(FundingPayment, :count).by(1)
  end

  it 'is idempotent on (position, funding_time) — no double-charge on retry' do
    expect {
      FundingJob.perform_now('BTCUSDT', 0.0003, 60_000.0, funding_time)
      FundingJob.perform_now('BTCUSDT', 0.0003, 60_000.0, funding_time)
    }.to change(FundingPayment, :count).by(1)
      .and change { LedgerEntry.where(event_type: 'FUNDING_FEE').count }.by(1)
  end
end
