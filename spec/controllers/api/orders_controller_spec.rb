require 'rails_helper'
require 'pp'

RSpec.describe Api::OrdersController, type: :controller do
  let(:account_id) { 'ACC-TEST' }
  let(:exchange) { instance_double('Exchange::PaperExchange') }
  let(:valid_attrs) do
    { symbol: 'RELIANCE', side: 'buy', quantity: 10, order_type: 'market', instrument_type: 'EQUITY' }
  end
  let(:invalid_attrs) { valid_attrs.merge(side: 'bad_side') }

  before do
    create(:account, account_id: account_id)
    request.headers['X-Account-Id'] = account_id
  end

  describe 'POST #create debug' do
    it 'shows what the controller sees' do
      post :create, params: { order: valid_attrs }
      puts "CONTROLLER RESPONSE BODY: #{response.body.first(500)}"
      puts "STATUS: #{response.status}"
    end
  end
end
