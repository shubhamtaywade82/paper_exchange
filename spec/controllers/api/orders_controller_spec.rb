require 'rails_helper'

# Minimal repro
RSpec.describe Api::OrdersController, type: :controller do
  let(:account_id) { 'ACC-TEST' }
  let(:valid_attrs) do
    { symbol: 'RELIANCE', side: 'buy', quantity: 10, order_type: 'market', instrument_type: 'EQUITY' }
  end

  before do
    create(:account, account_id: account_id)
    request.headers['X-Account-Id'] = account_id
  end

  it 'shows what order_params returns' do
    post :create, params: { order: valid_attrs.slice(:symbol, :side, :quantity, :order_type, :instrument_type) }
    puts "=== OUTER RESPONSE BODY ==="
    puts response.body[0..500]
    puts "=== END ==="
    puts "=== STATUS: #{response.status}"
  end
end
