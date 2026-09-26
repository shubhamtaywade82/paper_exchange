require 'rails_helper'

RSpec.describe Api::AccountsController, type: :controller do
  let(:account_id) { 'ACC-TEST' }

  before { request.headers['X-Account-Id'] = account_id }

  describe 'GET #show' do
    it 'returns 404 when the account does not exist' do
      get :show
      expect(response).to have_http_status(:not_found)
    end

    context 'with an existing account' do
      before { create(:account, account_id: account_id, margin: 100_000.0) }

      it 'returns the wallet split and live equity' do
        get :show
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['account_id']).to eq(account_id)
        expect(json['available_balance'].to_f).to eq(100_000.0)
        expect(json['locked_margin'].to_f).to eq(0.0)
        expect(json['equity'].to_f).to eq(100_000.0)
      end

      it 'reports fee-inclusive equity for an open leveraged position' do
        account = Account.find_by!(account_id: account_id)
        account.update!(margin: 10_000.0, available_balance: 10_000.0, current_equity: 10_000.0)
        Exchange::PaperExchange.new(account_id: account_id).submit_order(
          account_id: account_id, symbol: 'BTCUSDT', side: 'buy', quantity: 0.1, order_kind: 'market', instrument_type: 'CRYPTO_PERPETUAL',
          leverage: 5, margin_type: 'isolated', execution_price: 65_000.0
        )
        MarketData::MarkPriceStore.set('BTCUSDT', 66_000.0)

        get :show

        json = JSON.parse(response.body)
        expect(json['equity'].to_f).to eq(10_097.4)
        expect(json['drawdown'].to_f).to eq(0.0)
      end

      it 'reflects margin locked against an open leveraged position' do
        position = create(:paper_position,
          account_id: account_id,
          symbol: 'BTCUSDT',
          side: :long,
          quantity: 1,
          avg_price: 60_000.0,
          current_price: 60_000.0,
          leverage: 10)
        Exchange::MarginEngine.sync_position!(position, account_id: account_id)

        get :show
        json = JSON.parse(response.body)
        expect(json['locked_margin'].to_f).to eq(6_000.0)
        expect(json['available_balance'].to_f).to eq(94_000.0)
      end
    end
  end

  describe 'POST #reset' do
    let(:reset_account) { Account.find_by!(account_id: account_id) }

    it 'seeds the account with the requested margin from the query string' do
      post :reset, params: { margin: 100_000 }

      expect(response).to have_http_status(:ok)
      expect(reset_account.available_balance.to_f).to eq(100_000.0)
      expect(reset_account.margin.to_f).to eq(100_000.0)
      expect(JSON.parse(response.body)['balance'].to_f).to eq(100_000.0)
    end

    it 'accepts the margin in a JSON body' do
      post :reset, params: { margin: 25_000.5 }, as: :json

      expect(reset_account.available_balance.to_f).to eq(25_000.5)
    end

    it 'wipes positions and orders when re-seeding' do
      create(:account, account_id: account_id)
      create(:paper_position, account_id: account_id)

      post :reset, params: { margin: 100_000 }

      expect(::PaperExchange::PaperPosition.where(account_id: account_id)).to be_empty
    end

    # S11 regression guard: the wipe spans five tables; a failure midway
    # must roll the whole reset back instead of leaving a half-wiped account.
    it 'rolls the whole wipe back when a step fails mid-reset (atomic reset)' do
      account = create(:account, account_id: account_id, margin: 1_000.0)
      create(:paper_position, account_id: account_id, symbol: 'BTCUSDT')
      create(:paper_order, account_id: account_id, status: :open)
      # Stub the RELATION's delete_all (what the controller actually calls:
      # LedgerEntry.where(...).delete_all) — a class-level stub would miss it.
      relation = instance_double(ActiveRecord::Relation)
      allow(LedgerEntry).to receive(:where).with(account_id: account_id).and_return(relation)
      allow(relation).to receive(:delete_all).and_raise(RuntimeError, 'boom')

      expect { post :reset, params: { margin: 500.0 } }.to raise_error(RuntimeError, 'boom')

      expect(::PaperExchange::PaperPosition.where(account_id: account_id).count).to eq(1)
      expect(::PaperExchange::PaperOrder.where(account_id: account_id).count).to eq(1)
      account.reload
      expect(account.margin.to_f).to eq(1_000.0)
      expect(account.available_balance.to_f).to eq(1_000.0)
    end

    it 'keeps the env default margin when no margin is given' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('PAPER_EXCHANGE_MARGIN').and_return('10000.0')

      post :reset

      expect(reset_account.available_balance.to_f).to eq(10_000.0)
    end

    [ '0', '-5', 'abc', '1e999' ].each do |bad_margin|
      it "rejects margin=#{bad_margin} with 422 and leaves the account untouched" do
        create(:account, account_id: account_id, margin: 500_000.0)

        post :reset, params: { margin: bad_margin }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['error']).to match(/margin/)
        expect(reset_account.margin.to_f).to eq(500_000.0)
      end
    end
  end
end
