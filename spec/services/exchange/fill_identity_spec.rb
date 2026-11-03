require 'rails_helper'

# A fill slice is identified by its order and its sequence within that order. A
# slice cannot be booked twice, and every slice records how it was priced.
RSpec.describe Exchange::FillEngine, type: :service do
  let(:slippage) { instance_double('Exchange::SlippageEngine') }
  let(:engine) { described_class.new(slippage: slippage) }
  let(:order) { create(:paper_order, symbol: 'RELIANCE', side: 'buy', order_kind: 'market', quantity: 10, instrument_type: 'EQUITY') }
  let(:book) { { bid: 99.5, ask: 100.5, ltp: 100.0 } }

  before { create(:account, account_id: order.account_id) if Account.find_by(account_id: order.account_id).nil? }

  it 'numbers each slice within its order' do
    _, _, first = engine.fill(order, market_snapshot: book, instrument_type: 'EQUITY', quantity: 4, price: 100)
    _, _, second = engine.fill(order, market_snapshot: book, instrument_type: 'EQUITY', quantity: 6, price: 101)

    expect([ first.execution_key, second.execution_key ]).to eq([ "#{order.id}:1", "#{order.id}:2" ])
  end

  it 'records the rule rows that priced the slice and how its price was modelled' do
    _, _, trade = engine.fill(order, market_snapshot: book, instrument_type: 'EQUITY', quantity: 4, price: 100)

    expect(trade.charge_rule_ids).to be_present
    expect(trade.liquidity_source).to eq('top_of_book_model')
    expect(trade.total_charges).to be_a(BigDecimal)
  end

  it 'stamps the slice with simulated time inside a session, so a replay records its own clock' do
    session = Backtest::Session.new(risk_gate: false)
    session.at = Time.utc(2026, 11, 3, 4, 20)

    Backtest::Session.with(session) do
      _, _, trade = engine.fill(order, market_snapshot: book, instrument_type: 'EQUITY', quantity: 4, price: 100)
      expect(trade.traded_at).to eq(Time.utc(2026, 11, 3, 4, 20))
    end
  end

  it 'refuses a second slice that claims an execution key already booked for the order' do
    engine.fill(order, market_snapshot: book, instrument_type: 'EQUITY', quantity: 4, price: 100)

    expect {
      ::PaperExchange::PaperTrade.create!(
        paper_order: order, side: 'buy', quantity: 1, price: 100, charges: {}, total_charges: 0,
        fill_type: 'full', traded_at: Time.current, execution_key: "#{order.id}:1"
      )
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
