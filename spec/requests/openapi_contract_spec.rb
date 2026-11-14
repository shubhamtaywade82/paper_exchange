require 'rails_helper'

# #18: public/api-docs/openapi.yaml documents the response shapes the trading
# agent codes against. Each example compares the live response's keys with the
# documented 200 example, so a key that is missing or undocumented fails the
# build. The docs and the code cannot drift apart silently.
#
# Covered: GET /api/v1/account (including the nested wallet object) and
# GET /api/v1/performance. Not covered: /api/v1/exchange/status (no request spec
# exists for it yet) and the list endpoints, whose documented examples are arrays.
RSpec.describe 'OpenAPI response contract (#18)', type: :request do
  let(:account_id) { 'ACC-CONTRACT' }
  let(:headers) { { 'X-API-Key' => ENV.fetch('PAPER_EXCHANGE_API_KEY'), 'X-Account-Id' => account_id } }

  before { create(:account, account_id: account_id, margin: 10_000.0, currency: 'USDT') }

  def documented_example(path)
    doc = YAML.safe_load_file(Rails.root.join('public/api-docs/openapi.yaml'), aliases: true, permitted_classes: [ Date, Time, Symbol ])
    example = doc.dig('paths', path, 'get', 'responses', '200', 'content', 'application/json', 'example')
    raise "no documented 200 example for GET #{path}" if example.nil?

    example
  end

  it 'GET /api/v1/account returns exactly the documented keys, including wallet' do
    get '/api/v1/account', headers: headers
    expect(response).to have_http_status(:ok)

    example = documented_example('/api/v1/account')
    body = JSON.parse(response.body)

    expect(body.keys.sort).to eq(example.keys.sort)
    expect(body['wallet'].keys.sort).to eq(example['wallet'].keys.sort)
  end

  it 'GET /api/v1/performance returns exactly the documented keys' do
    get '/api/v1/performance', headers: headers
    expect(response).to have_http_status(:ok)

    expect(JSON.parse(response.body).keys.sort).to eq(documented_example('/api/v1/performance').keys.sort)
  end
end
