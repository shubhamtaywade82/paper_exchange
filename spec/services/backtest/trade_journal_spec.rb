require 'rails_helper'

# Builds fills directly in the exchange tables and checks the round trips the
# journal derives. The engine specs cover the same arithmetic end to end.
RSpec.describe Backtest::TradeJournal do
  let(:account_id) { 'ACC-JOURNAL' }
  let(:clock) { Time.utc(2026, 11, 2, 4, 0) }

  def fill!(side:, quantity:, price:, charges: '1', at: nil, reason: nil)
    order = PaperExchange::PaperOrder.create!(
      account_id: account_id, symbol: 'RELIANCE', instrument_type: 'EQUITY',
      side: side, quantity: quantity, order_kind: 'market', status: :filled,
      filled_quantity: quantity, placed_at: at || clock, filled_at: at || clock
    )
    PaperExchange::PaperTrade.create!(
      paper_order: order, side: side, quantity: quantity, price: price,
      charges: { total: charges }, total_charges: charges, fill_type: 'full', traded_at: at || clock
    )
    @reasons ||= {}
    @reasons[order.id] = reason if reason
    order
  end

  def trips(reasons = @reasons || {})
    described_class.build(account_id: account_id, exit_reasons: reasons)
  end

  before { create(:account, account_id: account_id, margin: 100_000.0) }

  it 'nets an add and a close into one trip at the average entry price' do
    fill!(side: 'buy', quantity: 10, price: 100, at: clock)
    fill!(side: 'buy', quantity: 5, price: 110, at: clock + 60)
    exit_order = fill!(side: 'sell', quantity: 15, price: 120, at: clock + 120, reason: 'signal')

    trip = trips.sole
    expect(trip).to include(direction: 'long', quantity: 15, exit_reason: 'signal', exit_order_id: exit_order.id)
    expect(trip[:entry_price]).to be_within(BigDecimal('0.0001')).of(BigDecimal('103.3333'))
    expect(trip[:gross_pnl]).to be_within(BigDecimal('0.0001')).of(BigDecimal('250'))
    expect(trip[:commission]).to eq(BigDecimal('3'))
    expect(trip[:net_pnl]).to be_within(BigDecimal('0.0001')).of(BigDecimal('247'))
  end

  it 'keeps a trip open across a partial close and closes it on the final exit' do
    fill!(side: 'buy', quantity: 10, price: 100, at: clock)
    fill!(side: 'sell', quantity: 4, price: 105, at: clock + 60, reason: 'take_profit')
    fill!(side: 'sell', quantity: 6, price: 95, at: clock + 120, reason: 'stop_loss')

    trip = trips.sole
    expect(trip[:gross_pnl]).to eq(BigDecimal('-10'))
    expect(trip[:exit_price]).to eq(BigDecimal('99'))
    expect(trip[:exit_reason]).to eq('stop_loss')
  end

  it 'splits a flip into two trips: the closed long, then the new short' do
    fill!(side: 'buy', quantity: 10, price: 100, at: clock)
    fill!(side: 'sell', quantity: 15, price: 90, at: clock + 60, reason: 'stop_loss')
    fill!(side: 'buy', quantity: 5, price: 80, at: clock + 120, reason: 'take_profit')

    first, second = trips
    expect(first).to include(direction: 'long', quantity: 10, exit_reason: 'stop_loss')
    expect(first[:gross_pnl]).to eq(BigDecimal('-100'))
    expect(second).to include(direction: 'short', quantity: 5, exit_reason: 'take_profit')
    expect(second[:gross_pnl]).to eq(BigDecimal('50'))
  end

  it 'labels a close whose order has no recorded reason as unmapped, never silently as a signal' do
    fill!(side: 'buy', quantity: 2, price: 100, at: clock)
    fill!(side: 'sell', quantity: 2, price: 101, at: clock + 60)

    expect(trips({}).sole[:exit_reason]).to eq('unmapped')
  end

  it 'reports the gross P&L that sums to the realized P&L the ledger would post' do
    fill!(side: 'buy', quantity: 3, price: 50, at: clock)
    fill!(side: 'sell', quantity: 3, price: 60, at: clock + 60, reason: 'signal')

    expect(trips.sum { |t| t[:gross_pnl] }).to eq(BigDecimal('30'))
  end
end
