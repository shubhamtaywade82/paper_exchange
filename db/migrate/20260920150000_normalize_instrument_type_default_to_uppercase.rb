# Issue #12: paper_exchange_positions.instrument_type default was 'equity'
# (lowercase) while every other column/code path uses 'EQUITY'. The model
# validator compares against DhanInstrumentCatalog::INSTRUMENT_TYPES (which
# delegate to DhanHQ's uppercase constants) and CryptoInstrumentCatalog::PERPETUAL.
# A position created via PositionManager.apply! always had its instrument_type
# passed in uppercase, but the column default could produce 'equity' rows
# elsewhere (direct SQL, etc.) that would then fail validation on save.
class NormalizeInstrumentTypeDefaultToUppercase < ActiveRecord::Migration[8.1]
  def up
    # Backfill any lowercase rows first so the constraint change is safe.
    execute "UPDATE paper_exchange_positions SET instrument_type = UPPER(instrument_type) WHERE instrument_type != UPPER(instrument_type)"
    change_column_default :paper_exchange_positions, :instrument_type, "EQUITY"
  end

  def down
    change_column_default :paper_exchange_positions, :instrument_type, "equity"
  end
end
