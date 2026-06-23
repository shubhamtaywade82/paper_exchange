require 'rails_helper'

RSpec.describe Exchange::BinanceUSDMFuturesCatalog, type: :service do
  describe '.fetch_instruments' do
    let(:response_body) do
      {
        'symbols' => [
          {
            'symbol' => 'BTCUSDT',
            'baseAsset' => 'BTC',
            'quoteAsset' => 'USDT',
            'contractType' => 'PERPETUAL',
            'underlyingType' => 'COIN',
            'pricePrecision' => 2,
            'quantityPrecision' => 3,
            'filters' => [
              { 'filterType' => 'PRICE_FILTER', 'tickSize' => '0.10' },
              { 'filterType' => 'LOT_SIZE', 'minQty' => '0.001', 'maxQty' => '1000', 'stepSize' => '0.001' },
              { 'filterType' => 'NOTIONAL', 'notional' => '5.0' }
            ]
          }
        ]
      }.to_json
    end

    before do
      stub_request(:get, %r{fapi\.binance\.com/fapi/v1/exchangeInfo})
        .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns normalized instruments' do
      results = described_class.fetch_instruments
      expect(results).to be_an(Array)
      expect(results.first[:symbol]).to eq('BTCUSDT')
      expect(results.first[:tick_size]).to eq(0.10)
      expect(results.first[:min_notional]).to eq(5.0)
    end
  end

  describe '.fetch_instrument' do
    before do
      stub_request(:get, %r{fapi\.binance\.com/fapi/v1/exchangeInfo})
        .to_return(status: 200, body: { 'symbols' => [ { 'symbol' => 'BTCUSDT' } ] }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'finds a specific instrument' do
      result = described_class.fetch_instrument('BTCUSDT')
      expect(result[:symbol]).to eq('BTCUSDT')
    end
  end
end
