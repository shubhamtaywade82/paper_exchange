require 'rails_helper'

# Each protection is evaluated on the price it declares, and on no other (I3).
RSpec.describe ProtectionMonitorJob, 'declared trigger sources', type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:account_id) { 'ACC-TRIGGER' }
  let!(:account) { create(:account, account_id: account_id, margin: 100_000.0) }
  let!(:position) do
    create(:paper_position, account_id: account_id, symbol: 'RELIANCE', side: :long, quantity: 10,
      avg_price: 100.0, current_price: 50.0, instrument_type: 'EQUITY')
  end

  before do
    MarketData::QuoteStore.clear
    MarketData::MarkPriceStore.clear
    ActiveJob::Base.queue_adapter = :test
  end

  def protect(source, trigger: 95.0)
    PositionProtection.create!(paper_position: position, account_id: account_id, venue: 'paper',
      instrument_id: 'RELIANCE', protection_type: 'stop_loss', trigger_price: trigger, quantity: 10,
      trigger_source: source)
  end

  def quote!(ltp: 96.0, bid: 95.5, ask: 96.5, mark: 96.0)
    MarketData::QuoteStore.set(venue: 'paper', instrument_id: 'RELIANCE', bid: bid, ask: ask,
      bid_quantity: nil, ask_quantity: nil, ltp: ltp, mark_price: mark, exchange_timestamp: Time.current.iso8601(6))
  end

  it 'refuses a trigger source outside the declared list' do
    protection = PositionProtection.new(paper_position: position, account_id: account_id, venue: 'paper',
      instrument_id: 'RELIANCE', protection_type: 'stop_loss', trigger_price: 95.0, quantity: 10,
      trigger_source: 'vwap')

    expect(protection).not_to be_valid
  end

  describe 'last_trade' do
    it 'triggers on the last trade, even when the mark is above the stop' do
      protection = protect('last_trade')
      quote!(ltp: 94.0, mark: 99.0)

      described_class.perform_now

      expect(protection.reload.status).to eq('triggered')
    end
  end

  describe 'mark' do
    it 'does not trigger on a last trade that is below the stop when the mark is not' do
      protection = protect('mark')
      quote!(ltp: 94.0, mark: 99.0)

      described_class.perform_now

      expect(protection.reload.status).to eq('active')
    end
  end

  describe 'bid_ask' do
    it 'uses the bid for a long, so a bid through the stop triggers it' do
      protection = protect('bid_ask')
      quote!(ltp: 96.0, bid: 94.0, ask: 96.5)

      described_class.perform_now

      expect(protection.reload.status).to eq('triggered')
    end

    it 'does not trigger on a last trade through the stop when the bid is above it' do
      protection = protect('bid_ask')
      quote!(ltp: 94.0, bid: 96.0, ask: 96.5)

      described_class.perform_now

      expect(protection.reload.status).to eq('active')
    end
  end

  describe 'a declared source with no usable price' do
    it 'is not evaluated when there is no quote, and the position price is not used instead' do
      protection = protect('last_trade')

      described_class.perform_now

      expect(protection.reload.status).to eq('active')
      expect(position.reload.quantity.to_f).to eq(10.0)
    end

    it 'is recorded once per window, not once per run' do
      protect('last_trade')

      3.times { described_class.perform_now }

      expect(RiskEvent.where(event_type: 'PROTECTION_PRICE_UNAVAILABLE').count).to eq(1)
    end

    it 'is refused for a stale quote' do
      protection = protect('last_trade')
      quote!(ltp: 94.0)

      travel_to(Time.current + 60.seconds) { described_class.perform_now }

      expect(protection.reload.status).to eq('active')
      expect(RiskEvent.where(event_type: 'PROTECTION_PRICE_UNAVAILABLE').count).to eq(1)
    end

    it 'is never evaluated for index, which no quote on this venue supplies' do
      protection = protect('index')
      quote!(ltp: 94.0)

      described_class.perform_now

      expect(protection.reload.status).to eq('active')
    end
  end
end
