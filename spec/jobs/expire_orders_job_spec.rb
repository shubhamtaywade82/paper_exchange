require 'rails_helper'

# Audit S2 (T3.2): orders that never filled used to rest open forever with
# their locked margin parked — expire_order raised UnknownAttributeError
# because the expired_at column did not exist. The sweep now expires stale
# open orders and releases their margin.
RSpec.describe ExpireOrdersJob, type: :job do
  let(:account_id) { 'ACC-EXPIRE' }

  before do
    create(:account, account_id: account_id, margin: 10_000.0,
           available_balance: 9_900.0, locked_margin: 100.0)
  end

  it 'expires a stale open order, stamps expired_at, and releases its locked margin' do
    stale = create(:paper_order, account_id: account_id, status: :open,
                   placed_at: 2.hours.ago, locked_margin: 100.0)

    described_class.perform_now

    stale.reload
    expect(stale.status).to eq('expired')
    expect(stale.expired_at).to be_present
    expect(stale.locked_margin.to_f).to eq(0.0)

    account = Account.find_by(account_id: account_id)
    expect(account.locked_margin.to_f).to eq(0.0)
    expect(account.available_balance.to_f).to eq(10_000.0)
  end

  it 'leaves fresh open orders untouched' do
    fresh = create(:paper_order, account_id: account_id, status: :open,
                   placed_at: 5.minutes.ago, locked_margin: 100.0)

    described_class.perform_now

    expect(fresh.reload.status).to eq('open')
    expect(Account.find_by(account_id: account_id).locked_margin.to_f).to eq(100.0)
  end

  it 'leaves terminal orders untouched even when stale' do
    filled = create(:paper_order, account_id: account_id, status: :filled,
                    placed_at: 2.hours.ago, filled_quantity: 50)

    described_class.perform_now

    expect(filled.reload.status).to eq('filled')
  end

  it 'skips an order raced to a terminal state between selection and expiry' do
    stale = create(:paper_order, account_id: account_id, status: :open,
                   placed_at: 2.hours.ago, locked_margin: 100.0)
    # Simulate a concurrent fill between the job's SELECT and its expire:
    allow_any_instance_of(Exchange::PaperExchange).to receive(:expire_order) do
      stale.update_columns(status: PaperExchange::PaperOrder.statuses[:filled])
      raise PaperExchange::PaperOrder::StateError, 'cannot expire a filled order'
    end

    expect { described_class.perform_now }.not_to raise_error
  end
end
