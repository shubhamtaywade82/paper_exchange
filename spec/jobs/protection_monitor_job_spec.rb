require 'rails_helper'

# Architecture alignment (target architecture §5): ProtectionMonitorJob specs.
# The job scans active protections and triggers force-close orders when
# breach conditions are met — autonomously, without the trading bot.
RSpec.describe ProtectionMonitorJob, type: :job do
  let(:account) { create(:account, account_id: 'ACC-PROT-MONITOR', margin: 100_000.0, currency: 'USD') }

  let!(:position) do
    create(:paper_position,
      account_id: account.account_id,
      symbol: 'BTCUSDT',
      side: :long,
      quantity: 0.1,
      avg_price: 60_000.0,
      current_price: 60_000.0,
      instrument_type: Exchange::CryptoInstrumentCatalog::PERPETUAL,
      leverage: 10)
  end

  before do
    MarketData::MarkPriceStore.clear
    ActiveJob::Base.queue_adapter = :test
  end

  it 'triggers a stop_loss protection when the mark price breaches it' do
    protection = PositionProtection.create!(
      paper_position: position,
      account_id: account.account_id,
      venue: 'paper',
      instrument_id: 'BTCUSDT',
      protection_type: 'stop_loss',
      trigger_price: 54_000.0,
      quantity: 0.1
    )
    MarketData::MarkPriceStore.set('BTCUSDT', 53_000.0)

    described_class.perform_now

    protection.reload
    expect(protection.status).to eq('triggered')
    expect(position.reload.quantity.to_f).to eq(0.0)
    expect(RiskEvent.where(event_type: 'PROTECTION_TRIGGERED').count).to eq(1)
  end

  it 'does not trigger a stop_loss when the mark price is above it' do
    protection = PositionProtection.create!(
      paper_position: position,
      account_id: account.account_id,
      venue: 'paper', instrument_id: 'BTCUSDT',
      protection_type: 'stop_loss', trigger_price: 54_000.0, quantity: 0.1
    )
    MarketData::MarkPriceStore.set('BTCUSDT', 60_000.0)

    described_class.perform_now

    expect(protection.reload.status).to eq('active')
    expect(position.reload.quantity.to_f).to eq(0.1)
  end

  it 'triggers a take_profit protection when the mark price reaches it' do
    protection = PositionProtection.create!(
      paper_position: position,
      account_id: account.account_id,
      venue: 'paper', instrument_id: 'BTCUSDT',
      protection_type: 'take_profit', trigger_price: 66_000.0, quantity: 0.1
    )
    MarketData::MarkPriceStore.set('BTCUSDT', 67_000.0)

    described_class.perform_now

    expect(protection.reload.status).to eq('triggered')
    expect(position.reload.quantity.to_f).to eq(0.0)
  end
end
