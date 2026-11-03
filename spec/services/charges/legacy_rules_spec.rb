require 'rails_helper'

RSpec.describe Charges::LegacyRules, type: :service do
  it 'installs the same rows on every run' do
    expect { described_class.install! }.not_to change(ChargeRule, :count)
  end

  it 'covers every India product and every charged component' do
    rows = described_class.rows

    expect(rows.map { |r| r[:product] }.uniq).to match_array(%w[EQUITY_CASH FUTURES OPTIONS])
    expect(rows.map { |r| r[:component] }.uniq).to match_array(%w[brokerage stt sebi exchange_txn stamp_duty gst])
  end

  it 'marks every row with its legacy source, so none passes as verified' do
    expect(ChargeRule.pluck(:source_ref).uniq).to all(start_with('legacy:'))
  end

  it 'carries an operator override of an ENV rate into the row at install' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('PAPER_EXCHANGE_STT_OPTIONS_SELL', '0.15').and_return('0.2')

    row = described_class.rows.find { |r| r[:product] == 'OPTIONS' && r[:component] == 'stt' }

    expect(row[:rate]).to eq(BigDecimal('0.002'))
  end

  it 'defines GST as a component_sum over brokerage, SEBI and exchange charges only' do
    gst = described_class.rows.find { |r| r[:component] == 'gst' }

    expect(gst).to include(basis: 'component_sum', base_components: %w[brokerage sebi exchange_txn])
  end
end
