require 'rails_helper'

RSpec.describe Projections::PortfolioProjection, type: :service do
  let(:account_id) { 'ACC-TEST' }

  before { create(:account, account_id: account_id, margin: 100_000.0) }

  it 'returns portfolio summary' do
    summary = described_class.summary(account_id)
    expect(summary).to have_key(:positions_count)
    expect(summary).to have_key(:equity)
    # No trades and no open positions yet — equity is computed live as
    # margin + realized + unrealized (see Ledger::Ledger), never read from
    # the Account's cached current_equity column.
    expect(summary[:equity]).to eq(100_000.0)
  end

  it 'folds in live unrealized PnL from the mark price store, not the stale current_price column' do
    create(:paper_position, account_id: account_id, symbol: 'BTCUSDT', side: :long, quantity: 1, avg_price: 100.0, current_price: 100.0)
    allow(MarketData::MarkPriceStore).to receive(:get).with('BTCUSDT').and_return(150.0)

    summary = described_class.summary(account_id)

    expect(summary[:unrealized_pnl]).to eq(50.0)
    expect(summary[:equity]).to eq(100_050.0)
  end

  it 'counts trade fees: equity is available + locked + unrealized, not margin + gross pnl' do
    account = Account.find_by!(account_id: account_id)
    account.update!(available_balance: 98_697.4, locked_margin: 1_300.0)
    create(:paper_position, account_id: account_id, symbol: 'BTCUSDT', side: :long, quantity: 0.1, avg_price: 65_000.0, current_price: 65_000.0, leverage: 5)
    allow(MarketData::MarkPriceStore).to receive(:get).with('BTCUSDT').and_return(66_000.0)

    summary = described_class.summary(account_id)

    expect(summary[:equity]).to eq(100_097.4)
    expect(summary[:max_equity]).to eq(100_097.4)
    expect(summary[:drawdown]).to eq(0.0)
  end

  it 'derives drawdown from the fee-inclusive equity' do
    Account.find_by!(account_id: account_id).update!(available_balance: 90_000.0)

    summary = described_class.summary(account_id)

    expect(summary[:equity]).to eq(90_000.0)
    expect(summary[:max_equity]).to eq(100_000.0)
    expect(summary[:drawdown]).to eq(10.0)
  end
end
