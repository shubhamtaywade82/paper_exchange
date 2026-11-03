require 'rails_helper'

RSpec.describe Markets::OrderRules, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  # 2026-11-03 10:00 IST: an open NSE session.
  let(:now) { Time.utc(2026, 11, 3, 4, 30) }
  let(:exchange) { Markets::Exchange.create!(code: 'NSE', time_zone: 'Asia/Kolkata') }

  def order(**attrs)
    { symbol: 'RELIANCE', instrument_type: 'EQUITY', side: 'buy', quantity: 10, order_kind: 'bounded',
      price: 100.05, account_id: 'ACC-RULES' }.merge(attrs)
  end

  def equity!(lot: 1, tick: '0.05', freeze: nil, valid_from: Time.utc(2026, 1, 1), valid_until: nil)
    instrument = Markets::Instrument.create!(exchange: exchange, exchange_segment: 'NSE_EQ', security_id: '2885',
      symbol: 'RELIANCE', instrument_type: 'EQUITY')
    Markets::InstrumentSpec.create!(instrument: instrument, valid_from: valid_from, valid_until: valid_until,
      lot_size: lot, tick_size: tick, freeze_quantity: freeze, settlement_type: 'cash',
      source: 'spec', source_checksum: 'spec')
    Markets::TradingCalendarDay.create!(exchange: exchange, segment: 'NSE_EQ', trade_date: Date.new(2026, 11, 3),
      status: 'open', session_open_at: Time.utc(2026, 11, 3, 3, 45), session_close_at: Time.utc(2026, 11, 3, 10, 0),
      source_ref: 'spec')
    instrument
  end

  def refusal(attrs, at: now)
    described_class.validate!(attrs, at: at)
    nil
  rescue described_class::Refused => e
    e.message
  end

  describe 'always on' do
    %w[FUTCOM FUTCUR OPTFUT OPTCUR].each do |type|
      it "refuses #{type}, whose exchange rules are not loaded, without consulting the switch" do
        allow(Markets::Enforcement).to receive(:enforce?).and_return(false)

        expect(refusal(order(instrument_type: type))).to match(/#{type} is not supported until its exchange rules are loaded/)
      end
    end

    it 'does not refuse an equity order when enforcement is off, even with no instrument row' do
      allow(Markets::Enforcement).to receive(:enforce?).and_return(false)

      expect(refusal(order)).to be_nil
    end

    it 'leaves crypto to its own rules' do
      allow(Markets::Enforcement).to receive(:enforce?).and_return(true)

      expect(refusal(order(symbol: 'BTCUSDT', instrument_type: 'CRYPTO_PERPETUAL', price: nil))).to be_nil
    end
  end

  describe 'when enforcement is on' do
    before { allow(Markets::Enforcement).to receive(:enforce?).and_return(true) }

    it 'refuses an equity with no instrument master entry' do
      expect(refusal(order)).to eq('order refused: no instrument master entry for RELIANCE EQUITY')
    end

    it 'refuses a quantity that is not a lot multiple' do
      equity!(lot: 5)

      expect(refusal(order(quantity: 12, price: 100.05))).to match(/not a multiple of the lot size 5/)
    end

    it 'accepts a lot multiple' do
      equity!(lot: 5)

      expect(refusal(order(quantity: 15, price: 100.05))).to be_nil
    end

    it 'refuses a limit price that is off the tick' do
      equity!(tick: '0.05')

      expect(refusal(order(price: 100.03))).to match(/price 100.03 is not on the tick size 0.05/)
    end

    it 'checks a stop trigger price against the tick too' do
      equity!(tick: '0.05')

      expect(refusal(order(order_kind: 'stop_loss', price: nil, trigger_price: 99.01))).to match(/trigger_price 99.01 is not on the tick/)
    end

    it 'refuses a quantity above the freeze quantity rather than splitting it silently' do
      equity!(freeze: 1800)

      expect(refusal(order(quantity: 1900))).to match(/exceeds the freeze quantity 1800; split the order/)
    end

    it 'refuses an instrument whose spec is not in force at the event time' do
      equity!(valid_from: Time.utc(2027, 1, 1))

      expect(refusal(order)).to match(/has no instrument spec in force/)
    end

    it 'refuses an ambiguous instrument rather than choosing one' do
      equity!
      other = Markets::Instrument.create!(exchange: exchange, exchange_segment: 'BSE_EQ', security_id: '500325',
        symbol: 'RELIANCE', instrument_type: 'EQUITY')
      Markets::InstrumentSpec.create!(instrument: other, valid_from: Time.utc(2026, 1, 1), lot_size: 1,
        tick_size: 0.05, settlement_type: 'cash', source: 'spec', source_checksum: 'spec')

      expect(refusal(order)).to match(/matches more than one instrument/)
    end

    it 'refuses an order when the trading calendar has no entry for the day' do
      equity!
      Markets::TradingCalendarDay.delete_all

      expect(refusal(order)).to match(/no trading calendar entry for NSE NSE_EQ on 2026-11-03/)
    end

    it 'refuses an order on a closed day' do
      equity!
      Markets::TradingCalendarDay.update_all(status: 'closed', session_open_at: nil, session_close_at: nil)

      expect(refusal(order)).to match(/is closed on 2026-11-03/)
    end

    it 'refuses an order outside the session window' do
      equity!

      expect(refusal(order, at: Time.utc(2026, 11, 3, 10, 30))).to match(/outside the NSE NSE_EQ session/)
    end

    it 'accepts a conforming order inside the session' do
      equity!

      expect(refusal(order)).to be_nil
    end
  end
end
