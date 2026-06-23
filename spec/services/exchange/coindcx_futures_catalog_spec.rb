require 'rails_helper'

RSpec.describe Exchange::CoinDCXFuturesCatalog, type: :service do
  describe '.fetch_instruments' do
    let(:fake_response) do
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
      ]
    end

    before do
      fake_client = instance_double('CoinDCX::Client')
      allow(CoinDCX::Client).to receive(:new).and_return(fake_client)
      allow(fake_client).to receive_message_chain(:futures, :market_data, :list_active_instruments).and_return(fake_response)
    end

    it 'returns normalized instruments' do
      results = described_class.fetch_instruments
      expect(results).to be_an(Array)
      first = results.first
      expect(first[:symbol]).to eq('B-BTC_USDT')
      expect(first[:maker_fee]).to eq(0.0002)
      expect(first[:taker_fee]).to eq(0.0005)
    end
  end
end
