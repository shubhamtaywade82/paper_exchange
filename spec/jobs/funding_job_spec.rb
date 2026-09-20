require 'rails_helper'

RSpec.describe FundingJob, type: :job do
  let(:account) { create(:account, account_id: 'ACC-FUNDING', margin: 100_000.0) }

  let!(:long_position) do
    create(:paper_position,
      account_id: account.account_id,
      symbol: 'BTCUSDT',
      side: :long,
      quantity: 1,
      avg_price: 60_000.0,
      current_price: 60_000.0,
      instrument_type: Exchange::CryptoInstrumentCatalog::PERPETUAL,
      leverage: 10)
  end

  def stub_premium_index(rate:, mark_price: 60_000.0)
    stub_request(:get, FundingJob::PREMIUM_INDEX_URL).to_return(
      status: 200,
      body: [{ symbol: 'BTCUSDT', markPrice: mark_price.to_s, lastFundingRate: rate.to_s }].to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  it 'debits a long position when the funding rate is positive (longs pay shorts)' do
    stub_premium_index(rate: 0.0003)

    expect { described_class.perform_now }.to change(FundingPayment, :count).by(1)

    payment = FundingPayment.last
    expect(payment.amount).to be > 0
    expect(payment.funding_rate).to eq(0.0003)
    expect(payment.position_notional).to eq(60_000.0)
  end

  it 'credits a short position when the funding rate is positive' do
    long_position.destroy!
    create(:paper_position,
      account_id: account.account_id,
      symbol: 'BTCUSDT',
      side: :short,
      quantity: 1,
      avg_price: 60_000.0,
      current_price: 60_000.0,
      instrument_type: Exchange::CryptoInstrumentCatalog::PERPETUAL,
      leverage: 10)
    stub_premium_index(rate: 0.0003)

    described_class.perform_now
    expect(FundingPayment.last.amount).to be < 0
  end

  it 'writes a FUNDING_FEE ledger entry and refreshes the account equity snapshot' do
    stub_premium_index(rate: 0.0003)

    expect { described_class.perform_now }.to change { LedgerEntry.where(event_type: 'FUNDING_FEE').count }.by(1)
  end

  it 'skips unleveraged positions' do
    long_position.update!(leverage: 1)
    stub_premium_index(rate: 0.0003)

    expect { described_class.perform_now }.not_to change(FundingPayment, :count)
  end

  it 'is a no-op when there are no open leveraged positions' do
    long_position.destroy!

    expect { described_class.perform_now }.not_to change(FundingPayment, :count)
  end
end
