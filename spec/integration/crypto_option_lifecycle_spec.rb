require 'rails_helper'

# CRYPTO_OPTION: USDT-settled, long-premium-only crypto options (Binance
# Options symbology). Covers the open/close accounting, the guards that keep
# the account from writing options, the Binance fee model and 08:00 UTC
# expiry settlement against the UNDERLYING's mark price.
RSpec.describe 'CRYPTO_OPTION lifecycle', type: :integration do
  include ActiveSupport::Testing::TimeHelpers

  let(:account_id) { 'ACC-CRYPTO-OPT' }
  let(:exchange) { Exchange::PaperExchange.new(account_id: account_id) }
  let(:expiry) { Date.new(2026, 10, 30) }
  let(:now) { Time.utc(2026, 10, 25, 4, 41) }
  let(:call_contract) do
    { symbol: 'BTC-261030-81000-C', instrument_type: 'CRYPTO_OPTION', option_type: 'CE',
      strike_price: 81_000, expiry_date: expiry.iso8601 }
  end

  def submit(**attrs)
    exchange.submit_order({ account_id: account_id, order_kind: 'market', leverage: 1 }.merge(call_contract).merge(attrs))
  end

  def account
    Account.find_by!(account_id: account_id)
  end

  def position
    PaperExchange::PaperPosition.find_by!(account_id: account_id, symbol: call_contract[:symbol])
  end

  before do
    travel_to(now)
    MarketData::MarkPriceStore.clear
    create(:account, account_id: account_id, margin: 10_000.0, currency: 'USDT')
  end

  after { travel_back }

  describe 'opening a long call' do
    it 'locks the full premium and charges the index-based fee, capped at 10% of premium' do
      MarketData::MarkPriceStore.set('BTCUSDT', 80_932.0)

      order = submit(side: 'buy', quantity: 0.5, execution_price: 1_250.0, client_order_id: 'opt-open-1')

      expect(order.status).to eq('filled')
      expect(position.side).to eq('long')
      expect(position.quantity.to_f).to eq(0.5)
      expect(position.option_type).to eq('CE')
      expect(position.strike_price.to_f).to eq(81_000.0)
      expect(position.expiry_date).to eq(expiry)
      # premium 1250 x 0.5 = 625 is locked; leverage is irrelevant for a paid premium
      expect(position.initial_margin.to_f).to eq(625.0)
      # fee = min(0.0003 x 80932 x 0.5, 0.10 x 625) = min(12.1398, 62.5)
      fee = order.paper_trades.first.total_charges.to_f
      expect(fee).to be_within(1e-6).of(12.1398)
      expect(account.available_balance.to_f).to be_within(1e-6).of(10_000.0 - 625.0 - 12.1398)
    end

    it 'charges the 10% premium cap when the underlying price was never pushed' do
      order = submit(side: 'buy', quantity: 1, execution_price: 40.0)

      expect(order.paper_trades.first.total_charges.to_f).to be_within(1e-9).of(4.0)
    end

    it 'caps the fee at 10% of premium for a deep out-of-the-money option' do
      MarketData::MarkPriceStore.set('BTCUSDT', 80_932.0)

      order = submit(side: 'buy', quantity: 1, execution_price: 5.0)

      # 0.0003 x 80932 = 24.28 > cap 0.5
      expect(order.paper_trades.first.total_charges.to_f).to be_within(1e-9).of(0.5)
    end
  end

  describe 'guards' do
    it 'refuses a sell that is not reduce_only: no option writing' do
      expect { submit(side: 'sell', quantity: 1, execution_price: 1_000.0) }
        .to raise_error(Exchange::OrderValidationError, /reduce_only/)
      expect(PaperExchange::PaperPosition.where(account_id: account_id).count).to eq(0)
    end

    it 'refuses leverage above 1' do
      expect { submit(side: 'buy', quantity: 1, execution_price: 1_000.0, leverage: 5) }
        .to raise_error(Exchange::OrderValidationError, /leverage must be 1/)
    end

    it 'refuses contract fields that disagree with the symbol' do
      expect { submit(side: 'buy', quantity: 1, execution_price: 1_000.0, option_type: 'PE') }
        .to raise_error(Exchange::OrderValidationError, /option_type/)
      expect { submit(side: 'buy', quantity: 1, execution_price: 1_000.0, strike_price: 80_000) }
        .to raise_error(Exchange::OrderValidationError, /strike_price/)
      expect { submit(side: 'buy', quantity: 1, execution_price: 1_000.0, expiry_date: '2026-10-31') }
        .to raise_error(Exchange::OrderValidationError, /expiry_date/)
    end

    it 'refuses a malformed option symbol' do
      expect { submit(side: 'buy', quantity: 1, execution_price: 1_000.0, symbol: 'BTCUSDT') }
        .to raise_error(Exchange::OrderValidationError, /must look like/)
    end

    it 'refuses to buy a contract at or after its 08:00 UTC expiry' do
      travel_to(Time.utc(2026, 10, 30, 8, 0))

      expect { submit(side: 'buy', quantity: 1, execution_price: 10.0) }
        .to raise_error(Exchange::OrderValidationError, /expired/)
    end

    it 'refuses a crypto option on an INR account' do
      account.update!(currency: 'INR')

      expect { submit(side: 'buy', quantity: 1, execution_price: 1_000.0) }
        .to raise_error(Exchange::PaperExchange::RiskCheckFailedError, /CURRENCY_MISMATCH_REJECTED/)
    end

    it 'refuses a premium the account cannot pay' do
      expect { submit(side: 'buy', quantity: 10, execution_price: 1_250.0) }
        .to raise_error(Ledger::InsufficientMarginError)
      expect(account.available_balance.to_f).to eq(10_000.0)
      expect(PaperExchange::PaperPosition.where(account_id: account_id).where.not(quantity: 0)).to be_empty
    end
  end

  describe 'closing' do
    it 'realizes premium PnL on a reduce_only sell and releases the premium lock' do
      submit(side: 'buy', quantity: 1, execution_price: 100.0)
      after_open = account.available_balance.to_f

      order = submit(side: 'sell', quantity: 5, execution_price: 160.0, reduce_only: true)

      expect(order.status).to eq('filled')
      expect(order.quantity.to_f).to eq(1.0) # clamped to the open size
      expect(position.quantity.to_f).to eq(0.0)
      expect(account.locked_margin.to_f).to eq(0.0)
      close_fee = order.paper_trades.first.total_charges.to_f
      expect(close_fee).to be_within(1e-9).of(16.0) # cap: no underlying price pushed
      # premium 100 unlocked + realized 60 - close fee
      expect(account.available_balance.to_f).to be_within(1e-6).of(after_open + 100.0 + 60.0 - close_fee)
    end
  end

  describe OptionExpiryJob do
    before { submit(side: 'buy', quantity: 2, execution_price: 1_250.0) }

    it 'does nothing before 08:00 UTC on the expiry date' do
      MarketData::MarkPriceStore.set('BTCUSDT', 83_000.0)

      OptionExpiryJob.new.perform(now: Time.utc(2026, 10, 30, 7, 59))

      expect(position.quantity.to_f).to eq(2.0)
    end

    it 'settles an in-the-money call at intrinsic value against the underlying mark' do
      MarketData::MarkPriceStore.set('BTCUSDT', 83_000.0)
      # The option's own mark is a premium and must not be read as the underlying
      MarketData::MarkPriceStore.set('BTC-261030-81000-C', 1_900.0)
      travel_to(Time.utc(2026, 10, 30, 8, 5))

      OptionExpiryJob.new.perform(now: Time.current.utc)

      expect(position.quantity.to_f).to eq(0.0)
      settlement = PaperExchange::PaperOrder.find_by!(account_id: account_id, client_order_id: "expiry-#{position.id}")
      expect(settlement.paper_trades.first.price.to_f).to eq(2_000.0)
      expect(Ledger::Ledger.compute_realized_pnl(account_id)).to be_within(1e-6).of((2_000.0 - 1_250.0) * 2)
      expect(RiskEvent.where(account_id: account_id, event_type: 'OPTION_EXPIRED').count).to eq(1)
    end

    it 'expires an out-of-the-money call worthless, losing exactly the premium' do
      MarketData::MarkPriceStore.set('BTCUSDT', 79_000.0)
      travel_to(Time.utc(2026, 10, 30, 8, 5))

      OptionExpiryJob.new.perform(now: Time.current.utc)

      expect(position.quantity.to_f).to eq(0.0)
      expect(Ledger::Ledger.compute_realized_pnl(account_id)).to be_within(1e-6).of(-2_500.0)
      expect(account.locked_margin.to_f).to eq(0.0)
    end

    it 'defers settlement when the underlying price is missing instead of settling on the premium' do
      MarketData::MarkPriceStore.set('BTC-261030-81000-C', 1_900.0)
      travel_to(Time.utc(2026, 10, 30, 8, 5))

      OptionExpiryJob.new.perform(now: Time.current.utc)

      expect(position.quantity.to_f).to eq(2.0)
      deferred = RiskEvent.find_by!(account_id: account_id, event_type: 'OPTION_SETTLEMENT_DEFERRED')
      expect(deferred.details['underlying']).to eq('BTCUSDT')
    end
  end

  it 'reports the contract fields on GET positions' do
    submit(side: 'buy', quantity: 1, execution_price: 100.0)

    projected = Projections::PositionProjection.for_account(account_id).first

    expect(projected).to include(instrument_type: 'CRYPTO_OPTION', option_type: 'CE', expiry_date: expiry)
    expect(projected[:strike_price].to_f).to eq(81_000.0)
  end
end
