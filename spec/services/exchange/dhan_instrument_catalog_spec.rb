require 'rails_helper'

RSpec.describe Exchange::DhanInstrumentCatalog, type: :service do
  describe '.index_underlying?' do
    it 'returns true for indices' do
      expect(described_class.index_underlying?('NIFTY')).to be_truthy
      expect(described_class.index_underlying?('BANKNIFTY')).to be_truthy
      expect(described_class.index_underlying?('nifty')).to be_truthy
    end

    it 'returns false for non-indices' do
      expect(described_class.index_underlying?('RELIANCE')).to be_falsey
      expect(described_class.index_underlying?('HDFCBANK')).to be_falsey
    end
  end

  describe '.valid_instrument_types' do
    it 'returns Dhan instrument enums' do
      types = described_class.valid_instrument_types
      expect(types).to include('EQUITY', 'FUTIDX', 'OPTIDX', 'FUTSTK', 'OPTSTK', 'FUTCUR', 'OPTCUR')
    end
  end

  describe '.validate_tradeable!' do
    context 'with index as equity' do
      it 'raises ArgumentError' do
        expect {
          described_class.validate_tradeable!(symbol: 'NIFTY', instrument_type: 'EQUITY', exchange_segment: 'NSE_FNO')
        }.to raise_error(ArgumentError, /does not support EQUITY/)
      end
    end

    context 'with index as FUTIDX' do
      it 'does not raise' do
        expect {
          described_class.validate_tradeable!(symbol: 'NIFTY', instrument_type: 'FUTIDX', exchange_segment: 'NSE_FNO')
        }.not_to raise_error
      end
    end

    context 'with equity symbol' do
      it 'allows equity instrument type' do
        expect {
          described_class.validate_tradeable!(symbol: 'RELIANCE', instrument_type: 'EQUITY', exchange_segment: 'NSE_EQ')
        }.not_to raise_error
      end
    end
  end
end
