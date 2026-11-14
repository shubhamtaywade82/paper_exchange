require 'rails_helper'

RSpec.describe Api::FundingEventsController, type: :controller do
  let(:funding_time) { '2026-09-20T08:00:00Z' }
  let(:parsed_time) { Time.zone.parse(funding_time) }

  describe 'POST #create' do
    it 'enqueues FundingJob with the pushed rate and settlement time' do
      expect {
        post :create, params: { symbol: 'btcusdt', funding_rate: '0.0003', mark_price: '65000.0', funding_time: funding_time }
      }.to have_enqueued_job(FundingJob).with('BTCUSDT', 0.0003, 65000.0, parsed_time)

      expect(response).to have_http_status(:accepted)
      expect(JSON.parse(response.body)['symbol']).to eq('BTCUSDT')
    end

    it 'defaults mark_price to nil when not supplied' do
      expect {
        post :create, params: { symbol: 'BTCUSDT', funding_rate: '0.0003', funding_time: funding_time }
      }.to have_enqueued_job(FundingJob).with('BTCUSDT', 0.0003, nil, parsed_time)
    end

    it 'returns 400 when symbol is missing' do
      post :create, params: { funding_rate: '0.0003', funding_time: funding_time }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 when funding_rate is missing' do
      post :create, params: { symbol: 'BTCUSDT', funding_time: funding_time }
      expect(response).to have_http_status(:bad_request)
    end

    # #60: funding_time is the idempotency key. Without it the job used to
    # skip every later settlement on the position, so it is now a 400.
    it 'returns 400 when funding_time is missing, and enqueues nothing' do
      expect {
        post :create, params: { symbol: 'BTCUSDT', funding_rate: '0.0003' }
      }.not_to have_enqueued_job(FundingJob)

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to include('funding_time')
    end

    it 'returns 400 when funding_time is blank' do
      post :create, params: { symbol: 'BTCUSDT', funding_rate: '0.0003', funding_time: '' }
      expect(response).to have_http_status(:bad_request)
    end

    # M3 regression guards: an unbounded rate used to post monstrous fees;
    # an unparseable funding_time used to cast to nil and bypass the
    # (paper_position_id, funding_time) dedup index.
    it 'rejects garbage and out-of-band funding rates with 422' do
      [ 'garbage', '1.0', '-2.5', '1e9' ].each do |bad|
        post :create, params: { symbol: 'BTCUSDT', funding_rate: bad, funding_time: funding_time }
        expect(response).to have_http_status(:unprocessable_content), "expected 422 for #{bad.inspect}"
      end
    end

    it 'accepts rates at the settlement bound' do
      expect {
        post :create, params: { symbol: 'BTCUSDT', funding_rate: '0.05', funding_time: funding_time }
      }.to have_enqueued_job(FundingJob)

      expect(response).to have_http_status(:accepted)
    end

    it 'rejects garbage mark_price with 422' do
      post :create, params: { symbol: 'BTCUSDT', funding_rate: '0.0001', mark_price: 'garbage', funding_time: funding_time }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects an unparseable funding_time with 422 instead of casting to nil' do
      post :create, params: { symbol: 'BTCUSDT', funding_rate: '0.0001', funding_time: 'not-a-time' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to include('funding_time')
    end

    it 'rejects an out-of-range funding_time with 422 instead of a 500' do
      post :create, params: { symbol: 'BTCUSDT', funding_rate: '0.0001', funding_time: '2026-13-45T08:00:00Z' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to include('funding_time')
    end

    it 'passes a parseable funding_time through to the job' do
      expect {
        post :create, params: { symbol: 'BTCUSDT', funding_rate: '0.0001', funding_time: funding_time }
      }.to have_enqueued_job(FundingJob).with('BTCUSDT', 0.0001, nil, parsed_time)

      expect(response).to have_http_status(:accepted)
    end
  end
end
