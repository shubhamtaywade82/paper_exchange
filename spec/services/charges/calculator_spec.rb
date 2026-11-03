require 'rails_helper'

# India charges from effective-dated rule rows. The expected figures below are
# worked by hand from the formulas, with the legacy rates, so a regression in
# the arithmetic or the rounding shows up as a changed number.
RSpec.describe Charges::Calculator, type: :service do
  let(:calculator) { described_class.new }
  let(:trade_day) { Time.utc(2026, 11, 3, 4, 0) } # 09:30 IST on 2026-11-03

  def calc(**attrs)
    calculator.calculate(
      trade_price: BigDecimal('100'), quantity: BigDecimal('10'), at: trade_day, **attrs
    )
  end

  describe 'computed from the rule rows' do
    it 'costs an equity buy: brokerage floor, delivery STT, GST on the base' do
      charges = calc(side: 'buy', instrument_type: 'EQUITY')

      # turnover 1000: brokerage max(0.30, 20) = 20; STT 0.25; SEBI 0.10; txn 0.0145;
      # stamp 0.03 (buy only); GST 18% of (20 + 0.10 + 0.0145) = 3.62061.
      expect(charges).to include(brokerage: 20, stt: 0.25, sebi: 0.10, exchange_txn: 0.01,
        stamp_duty: 0.03, gst: 3.62, notional: 1000)
      expect(charges[:total]).to eq(24.02)
    end

    it 'costs an equity sell: intraday-rate STT and no stamp duty' do
      charges = calc(side: 'sell', instrument_type: 'EQUITY')

      expect(charges[:stt]).to eq(0.13) # 1000 x 0.0125% = 0.125, rounded half up
      expect(charges[:stamp_duty]).to eq(0)
    end

    it 'costs an index option sell at the options STT rate' do
      charges = calc(side: 'sell', instrument_type: 'OPTIDX')

      expect(charges[:stt]).to eq(1.5) # 1000 x 0.15%
      expect(charges[:total]).to eq(25.24)
    end

    it 'costs a future sell at the futures STT rate' do
      expect(calc(side: 'sell', instrument_type: 'FUTIDX')[:stt]).to eq(0.5) # 1000 x 0.05%
    end

    it 'returns the rule ids that priced the trade, so a charge can be traced to its rows' do
      charges = calc(side: 'buy', instrument_type: 'EQUITY')

      expect(charges[:rule_ids]).to match_array(ChargeRule.where(product: 'EQUITY_CASH').where.not(side: 'sell').pluck(:id))
    end

    it 'returns decimals, never floats' do
      charges = calc(side: 'buy', instrument_type: 'EQUITY')

      expect(charges.values_at(:brokerage, :stt, :gst, :total)).to all(be_a(BigDecimal))
    end
  end

  describe 'effective dating' do
    it 'applies the rate in force on the trade date, so a later change does not restate history' do
      legacy = ChargeRule.find_by!(product: 'EQUITY_CASH', component: 'sebi', side: 'both')
      legacy.update!(effective_until: Date.new(2026, 6, 30))
      ChargeRule.create!(product: 'EQUITY_CASH', component: 'sebi', side: 'both', basis: 'turnover',
        rate: BigDecimal('0.0005'), rounding_scale: 2, effective_from: Date.new(2026, 7, 1), source_ref: 'spec')

      old_trade = calc(side: 'buy', instrument_type: 'EQUITY', at: Time.utc(2026, 5, 4, 4, 0))
      new_trade = calc(side: 'buy', instrument_type: 'EQUITY', at: trade_day)

      expect(old_trade[:sebi]).to eq(0.10) # 1000 x 0.0001
      expect(new_trade[:sebi]).to eq(0.50) # 1000 x 0.0005
    end

    it 'refuses a trade on a date with no rule in force, rather than using the nearest rule' do
      legacy = ChargeRule.find_by!(product: 'EQUITY_CASH', component: 'sebi', side: 'both')
      legacy.update!(effective_until: Date.new(2026, 6, 30))

      expect { calc(side: 'buy', instrument_type: 'EQUITY', at: Time.utc(2026, 9, 1, 4, 0)) }
        .to raise_error(Charges::Calculator::MissingRule, /no sebi charge rule for EQUITY_CASH/)
    end
  end

  describe 'refusals' do
    it 'raises MissingRule when a component has no rows at all' do
      ChargeRule.where(product: 'EQUITY_CASH', component: 'stt').delete_all

      expect { calc(side: 'buy', instrument_type: 'EQUITY') }
        .to raise_error(Charges::Calculator::MissingRule, /no stt charge rule for EQUITY_CASH/)
    end

    it 'raises AmbiguousRule when two rows match the same side' do
      ChargeRule.create!(product: 'EQUITY_CASH', component: 'brokerage', side: 'buy', basis: 'turnover',
        rate: BigDecimal('0.0001'), rounding_scale: 2, effective_from: Date.new(2026, 4, 1), source_ref: 'spec')

      expect { calc(side: 'buy', instrument_type: 'EQUITY') }
        .to raise_error(Charges::Calculator::AmbiguousRule, /more than one brokerage rule/)
    end

    it 'refuses an instrument type with no product, such as a commodity future' do
      expect { calc(side: 'buy', instrument_type: 'FUTCOM') }
        .to raise_error(Charges::Calculator::MissingRule, /no charge rules for FUTCOM/)
    end

    it 'refuses a basis the database does not allow, so no unknown basis can be stored' do
      expect {
        ChargeRule.find_by!(product: 'EQUITY_CASH', component: 'sebi', side: 'both').update_column(:basis, 'premium')
      }.to raise_error(ActiveRecord::StatementInvalid, /charge_rules_basis_valid/)
    end
  end

  describe 'rule row validation' do
    it 'needs exactly one amount source for a computed component' do
      rule = ChargeRule.new(product: 'EQUITY_CASH', component: 'sebi', side: 'both', basis: 'turnover',
        rate: 0.1, flat_amount: 1, rounding_scale: 2, effective_from: Date.new(2026, 4, 1), source_ref: 'spec')

      expect(rule).not_to be_valid
      expect(rule.errors[:base]).to include('needs exactly one of rate or flat_amount')
    end

    it 'needs base components for a component_sum rule' do
      rule = ChargeRule.new(product: 'EQUITY_CASH', component: 'gst', side: 'both', basis: 'component_sum',
        rate: 0.18, rounding_scale: 2, effective_from: Date.new(2026, 4, 1), source_ref: 'spec')

      expect(rule).not_to be_valid
      expect(rule.errors[:base_components]).to be_present
    end

    it 'refuses a rule whose effective window ends before it starts' do
      rule = ChargeRule.new(product: 'EQUITY_CASH', component: 'sebi', side: 'both', basis: 'turnover',
        rate: 0.1, rounding_scale: 2, effective_from: Date.new(2026, 4, 1), effective_until: Date.new(2026, 3, 1),
        source_ref: 'spec')

      expect(rule).not_to be_valid
    end

    it 'refuses a second overlapping row for the same component and side at the database' do
      expect {
        ChargeRule.create!(product: 'EQUITY_CASH', component: 'sebi', side: 'both', basis: 'turnover',
          rate: BigDecimal('0.0002'), rounding_scale: 2, effective_from: Date.new(2026, 5, 1), source_ref: 'spec')
      }.to raise_error(ActiveRecord::StatementInvalid, /charge_rules_no_overlap/)
    end
  end
end
