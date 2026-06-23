require 'rails_helper'

RSpec.describe Exchange::CoinDcxFuturesCatalog, type: :service do
  describe '.fetch_instruments' do
    let(:response_body) do
      [
        {
          pair: 'B-BTC_USDT',
          position_currency_short_name: 'BTC',
          quote_currency_short_name: 'USDT',
          kind: 'perpetual',
          price_increment: '0.01',
          quantity_increment: '0.001',
          min_quantity: '0.001',
          max_quantity: '1000',
          min_notional: '5.0',
          maker_fee: 0.0002,
          taker_fee: 0.0005
        }
      ].to_json
    end

    before do
      stub_request(:get, %r{api\.coindcx\.com/exchange/v1/derivatives/futures/data/active_instruments})
        .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns normalized instruments' do
      results = described_class.fetch_instruments
      expect(results).to be_an(Array)
      expect(results.first[:symbol]).to eq('B-BTC_USDT')
      expect(results.first[:maker_fee]).to eq(0.0002)
      expect(results.first[:taker_fee]).to eq(0.0005)
    end
  end
end
