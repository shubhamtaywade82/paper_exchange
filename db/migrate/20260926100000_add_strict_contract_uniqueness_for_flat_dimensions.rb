# Audit M4 (T2.1): the composite unique index
# index_paper_positions_uniqueness covers (account_id, symbol,
# instrument_type, option_type, strike_price, expiry_date) — but EQUITY and
# CRYPTO_PERPETUAL contracts have NULL option_type/strike_price/expiry_date,
# and Postgres treats NULLs as distinct in unique indexes. The index
# therefore never fired for exactly the instrument types that trade most,
# and concurrent first fills could insert two position rows for the same
# contract. This partial expression index closes that gap; the composite
# index stays for options contracts (all columns non-NULL).
class AddStrictContractUniquenessForFlatDimensions < ActiveRecord::Migration[8.1]
  def up
    # NULL-dimension duplicate rows may already exist from the pre-lock
    # race: keep the newest row per contract and drop the rest, or the
    # unique index creation below would fail.
    execute <<~SQL
      DELETE FROM paper_exchange_positions a
      USING paper_exchange_positions b
      WHERE a.id < b.id
        AND a.account_id = b.account_id
        AND a.symbol = b.symbol
        AND a.instrument_type = b.instrument_type
        AND a.option_type IS NULL
        AND a.strike_price IS NULL
        AND a.expiry_date IS NULL
        AND b.option_type IS NULL
        AND b.strike_price IS NULL
        AND b.expiry_date IS NULL
    SQL

    add_index :paper_exchange_positions,
      %i[account_id symbol instrument_type],
      unique: true,
      name: "index_paper_positions_contract_strict",
      where: "option_type IS NULL AND strike_price IS NULL AND expiry_date IS NULL"
  end

  def down
    remove_index :paper_exchange_positions, name: "index_paper_positions_contract_strict"
  end
end
