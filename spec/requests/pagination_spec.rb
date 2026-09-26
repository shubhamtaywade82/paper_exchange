require 'rails_helper'

# Audit N6 (T5.4): orders / ledger / risk_events list endpoints use
# keyset pagination. The envelope is { "data": [...], "next_cursor": ... }
# and the cursor is opaque — these specs pin the CONTRACT: complete and
# duplicate-free walks, a total order on (sort_column, id) even when
# timestamps collide, the limit clamp, and 400 on tampered cursors.
RSpec.describe 'Cursor pagination (audit N6)', type: :request do
  let(:api_key) { ENV.fetch('PAPER_EXCHANGE_API_KEY') }
  let(:account_id) { 'ACC-PAGE' }
  let(:headers) { { 'X-API-Key' => api_key, 'X-Account-Id' => account_id } }

  before { create(:account, account_id: account_id) }

  # Walks every page of an endpoint with limit=2 and returns all items.
  def drain(path)
    items = []
    cursor = nil
    loop do
      get path, params: { limit: 2, cursor: cursor }.compact, headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_a(Hash)
      items.concat(body['data'])
      cursor = body['next_cursor']
      break if cursor.nil?
    end
    items
  end

  describe 'GET /api/ledger' do
    it 'pages through history completely, newest first, with the id tiebreak on equal timestamps' do
      t1 = 3.hours.ago
      t2 = 2.hours.ago
      t3 = 1.hour.ago
      a = create(:ledger_entry, account_id: account_id, occurred_at: t1, debit: 10)
      b = create(:ledger_entry, account_id: account_id, occurred_at: t1, debit: 20)
      c = create(:ledger_entry, account_id: account_id, occurred_at: t2, debit: 30)
      d = create(:ledger_entry, account_id: account_id, occurred_at: t3, debit: 40)
      e = create(:ledger_entry, account_id: account_id, occurred_at: t3, debit: 50)

      items = drain('/api/ledger')

      expect(items.map { |i| i['id'] }).to eq([ e.id, d.id, c.id, b.id, a.id ])
      expect(items.map { |i| i['debit'].to_f }).to eq([ 50, 40, 30, 20, 10 ])
    end

    it 'never leaks another account''s entries' do
      create(:ledger_entry, account_id: account_id, occurred_at: 1.hour.ago)
      create(:ledger_entry, account_id: 'ACC-OTHER', occurred_at: 2.hours.ago)

      expect(drain('/api/ledger').size).to eq(1)
    end

    it 'caps limit at MAX_LIMIT (500) even when the client asks for more' do
      now = Time.current
      rows = (1..501).map do |i|
        { account_id: account_id, event_type: 'TRADE', debit: 1, credit: 0,
          occurred_at: (now - i.seconds), created_at: now, updated_at: now }
      end
      LedgerEntry.insert_all!(rows)

      get '/api/ledger', params: { limit: 99_999 }, headers: headers

      body = JSON.parse(response.body)
      expect(body['data'].size).to eq(500)
      expect(body['next_cursor']).to be_present
    end

    it 'treats a non-positive or garbage limit as the default' do
      create(:ledger_entry, account_id: account_id, occurred_at: 1.hour.ago)

      [ '0', '-5', 'abc', nil ].each do |bad|
        get '/api/ledger', params: { limit: bad }, headers: headers
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET /api/orders' do
    it 'pages through orders newest-first and ends with a null cursor' do
      o1 = create(:paper_order, account_id: account_id, placed_at: 3.hours.ago)
      o2 = create(:paper_order, account_id: account_id, placed_at: 2.hours.ago)
      o3 = create(:paper_order, account_id: account_id, placed_at: 1.hour.ago)

      items = drain('/api/orders')

      expect(items.map { |i| i['id'] }).to eq([ o3.id, o2.id, o1.id ])
    end
  end

  describe 'GET /api/risk_events' do
    it 'keeps a total order when every event shares one created_at' do
      same = 30.minutes.ago
      events = 4.times.map { |i| create(:risk_event, account_id: account_id, event_type: 'TEST', created_at: same, details: { i: i }) }

      items = drain('/api/risk_events')

      expect(items.map { |i| i['id'] }).to eq(events.reverse.map(&:id))
    end
  end

  describe 'tampered cursors' do
    it 'returns 400 for a non-base64 cursor' do
      get '/api/ledger', params: { cursor: '!!!not-base64!!!' }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to include('cursor')
    end

    it 'returns 400 for a base64 cursor with a garbage payload' do
      get '/api/ledger', params: { cursor: Base64.urlsafe_encode64('garbage') }, headers: headers
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for a base64 cursor with a non-numeric id' do
      get '/api/ledger', params: { cursor: Base64.urlsafe_encode64('2026-09-26T00:00:00Z|abc') }, headers: headers
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for a base64 cursor with a non-timestamp' do
      get '/api/ledger', params: { cursor: Base64.urlsafe_encode64('not-a-time|42') }, headers: headers
      expect(response).to have_http_status(:bad_request)
    end
  end
end
