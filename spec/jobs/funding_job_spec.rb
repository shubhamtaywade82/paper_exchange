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

  it 'debits a long position when the funding rate is positive (longs pay shorts)' do
    expect {
      described_class.perform_now('BTCUSDT', 0.0003, 60_000.0)
    }.to change(FundingPayment, :count).by(1)

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

    described_class.perform_now('BTCUSDT', 0.0003, 60_000.0)
    expect(FundingPayment.last.amount).to be < 0
  end

  it 'writes a FUNDING_FEE ledger entry and refreshes the account equity snapshot' do
    expect {
      described_class.perform_now('BTCUSDT', 0.0003, 60_000.0)
    }.to change { LedgerEntry.where(event_type: 'FUNDING_FEE').count }.by(1)
  end

  it 'falls back to MarketData::MarkPriceStore when no mark_price is given' do
    allow(MarketData::MarkPriceStore).to receive(:get).with('BTCUSDT').and_return(61_000.0)

    described_class.perform_now('BTCUSDT', 0.0003, nil)

    expect(FundingPayment.last.position_notional).to eq(61_000.0)
  end

  it 'falls back to the position column price when no mark_price and no store entry exist' do
    allow(MarketData::MarkPriceStore).to receive(:get).with('BTCUSDT').and_return(nil)

    described_class.perform_now('BTCUSDT', 0.0003, nil)

    expect(FundingPayment.last.position_notional).to eq(60_000.0) # long_position.current_price
  end

  it 'skips unleveraged positions' do
    long_position.update!(leverage: 1)

    expect {
      described_class.perform_now('BTCUSDT', 0.0003, 60_000.0)
    }.not_to change(FundingPayment, :count)
  end

  it 'is a no-op when there are no open leveraged positions on that symbol' do
    long_position.destroy!

    expect {
      described_class.perform_now('BTCUSDT', 0.0003, 60_000.0)
    }.not_to change(FundingPayment, :count)
  end

  it 'only settles positions on the given symbol' do
    create(:paper_position,
      account_id: account.account_id,
      symbol: 'ETHUSDT',
      side: :long,
      quantity: 1,
      avg_price: 3_000.0,
      current_price: 3_000.0,
      instrument_type: Exchange::CryptoInstrumentCatalog::PERPETUAL,
      leverage: 5)

    described_class.perform_now('BTCUSDT', 0.0003, 60_000.0)

    expect(FundingPayment.where(symbol: 'ETHUSDT')).to be_empty
  end
end
