require 'rails_helper'

RSpec.describe Api::OrdersController, type: :controller do
  let(:account_id) { 'ACC-TEST' }
  let(:exchange) { instance_double('Exchange::PaperExchange') }

  let(:valid_attrs) do
    { symbol: 'RELIANCE', side: 'buy', quantity: 10, order_type: 'market', instrument_type: 'EQUITY' }
  end

  before do
    create(:account, account_id: account_id)
    request.headers['X-Account-Id'] = account_id
  end

  it 'debugs the create call' do
    post :create, params: { order: valid_attrs.slice(:symbol, :side, :quantity, :order_type, :instrument_type) }
    puts "STATUS=#{response.status}"
    puts "BODY=#{response.body[0..300]}"
  end
end
