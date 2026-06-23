require 'rails_helper'

RSpec.describe Exchange::CoinDCXFuturesCatalog, type: :service do
  describe '.fetch_instruments' do
    before do
      WebMock.enable!
      stub_request(:get, %r{api\.coindcx\.com/exchange/v1/derivatives/futures/data/active_instruments})
        .to_return(status: 200, body: "", headers: { 'Content-Type' => 'application/json' })
    end

    after do
      WebMock.reset!
      WebMock.disable_net_connect!(allow_localhost: true)
    end

    it 'returns normalized instruments' do
      results = described_class.fetch_instruments
      expect(results).to be_an(Array)
      expect(results.first[:symbol]).to eq('B-BTC_USDT')
      expect(results.first[:maker_fee]).to be_a(Numeric)
      expect(results.first[:taker_fee]).to be_a(Numeric)
    end
  end
end
