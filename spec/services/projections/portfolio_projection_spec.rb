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
end
