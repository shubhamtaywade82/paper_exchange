# Effective-dated reference data for multi-market execution (MULTI_MARKET_SPEC §5.1).
# Exclusion constraints need btree_gist.
class CreateMarketReferenceData < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"

    create_table :exchanges do |t|
      t.string :code, null: false                 # NSE, BSE, MCX, NCDEX
      t.string :time_zone, null: false            # IANA zone, e.g. Asia/Kolkata
      t.timestamps
    end
    add_index :exchanges, :code, unique: true
    add_check_constraint :exchanges, "time_zone <> ''", name: "exchanges_time_zone_present"

    create_table :instruments do |t|
      t.references :exchange, null: false, foreign_key: true
      t.string :exchange_segment, null: false     # vendor segment, validated against the source file
      t.string :security_id, null: false          # vendor identifier, always a string
      t.string :symbol, null: false
      t.string :instrument_type, null: false
      t.references :underlying, foreign_key: { to_table: :instruments }
      t.string :option_type
      t.decimal :strike_price, precision: 36, scale: 18
      t.date :expiry_date
      t.timestamps
    end
    add_index :instruments, %i[exchange_id exchange_segment security_id],
      unique: true, name: "index_instruments_on_identity"
    add_index :instruments, %i[symbol instrument_type expiry_date]
    add_check_constraint :instruments,
      "(instrument_type IN ('OPTIDX','OPTSTK','OPTFUT','OPTCUR','CRYPTO_OPTION')) = (option_type IS NOT NULL)",
      name: "instruments_option_fields_consistent"
    add_check_constraint :instruments,
      "option_type IS NULL OR option_type IN ('CE','PE')",
      name: "instruments_option_type_valid"
    add_check_constraint :instruments,
      "instrument_type NOT IN ('FUTIDX','FUTSTK','FUTCOM','FUTCUR','OPTIDX','OPTSTK','OPTFUT','OPTCUR','CRYPTO_OPTION') OR expiry_date IS NOT NULL",
      name: "instruments_expiry_required"

    create_table :instrument_specs do |t|
      t.references :instrument, null: false, foreign_key: true
      t.datetime :valid_from, null: false
      t.datetime :valid_until                     # null = open-ended
      t.decimal :lot_size, precision: 36, scale: 18, null: false
      t.decimal :tick_size, precision: 36, scale: 18, null: false
      t.decimal :freeze_quantity, precision: 36, scale: 18
      t.string :settlement_type, null: false      # cash | physical | none
      t.string :source, null: false
      t.string :source_checksum, null: false
      t.timestamps
    end
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE instrument_specs
            ADD CONSTRAINT instrument_specs_no_overlap
            EXCLUDE USING gist (
              instrument_id WITH =,
              tsrange(valid_from, COALESCE(valid_until, 'infinity'::timestamp), '[)') WITH &&
            )
        SQL
      end
    end
    add_check_constraint :instrument_specs, "lot_size > 0 AND tick_size > 0",
      name: "instrument_specs_positive_units"
    add_check_constraint :instrument_specs, "valid_until IS NULL OR valid_until > valid_from",
      name: "instrument_specs_valid_window"
    add_check_constraint :instrument_specs, "settlement_type IN ('cash','physical','none')",
      name: "instrument_specs_settlement_valid"

    create_table :trading_calendar_days do |t|
      t.references :exchange, null: false, foreign_key: true
      t.string :segment, null: false
      t.date :trade_date, null: false             # exchange-local calendar date
      t.string :status, null: false               # open | closed | special
      t.datetime :session_open_at
      t.datetime :session_close_at
      t.string :source_ref, null: false
      t.timestamps
    end
    add_index :trading_calendar_days, %i[exchange_id segment trade_date],
      unique: true, name: "index_calendar_days_on_session"
    add_check_constraint :trading_calendar_days, "status IN ('open','closed','special')",
      name: "trading_calendar_days_status_valid"
    add_check_constraint :trading_calendar_days,
      "status = 'closed' OR (session_open_at IS NOT NULL AND session_close_at > session_open_at)",
      name: "trading_calendar_days_session_window"

    create_table :market_rules do |t|
      t.references :exchange, null: false, foreign_key: true
      t.string :product, null: false              # EQUITY_CASH, FUTURES, OPTIONS
      t.string :rule_key, null: false             # e.g. squareoff_time, forced_exit_before_expiry_days
      t.jsonb :value, null: false
      t.date :effective_from, null: false
      t.date :effective_until
      t.string :source_ref, null: false
      t.timestamps
    end
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE market_rules
            ADD CONSTRAINT market_rules_no_overlap
            EXCLUDE USING gist (
              exchange_id WITH =,
              product WITH =,
              rule_key WITH =,
              daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[]') WITH &&
            )
        SQL
      end
    end

    create_table :charge_rules do |t|
      t.references :exchange, foreign_key: true   # null = applies to every exchange
      t.string :product, null: false              # EQUITY_CASH, FUTURES, OPTIONS
      t.string :side, null: false                 # buy | sell | both
      t.string :component, null: false            # brokerage | stt | exchange_txn | sebi | stamp_duty | gst
      t.string :basis, null: false                # turnover | flat | component_sum
      t.decimal :rate, precision: 20, scale: 10
      t.decimal :flat_amount, precision: 36, scale: 18
      t.decimal :minimum_amount, precision: 36, scale: 18
      t.decimal :maximum_amount, precision: 36, scale: 18
      t.integer :rounding_scale                   # required when a component is computed; no default
      t.jsonb :base_components                    # for component_sum: which components form the base
      t.date :effective_from, null: false
      t.date :effective_until
      t.string :source_ref, null: false
      t.timestamps
    end
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE charge_rules
            ADD CONSTRAINT charge_rules_no_overlap
            EXCLUDE USING gist (
              product WITH =,
              component WITH =,
              side WITH =,
              (COALESCE(exchange_id, 0)) WITH =,
              daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[]') WITH &&
            )
        SQL
      end
    end
    add_check_constraint :charge_rules, "side IN ('buy','sell','both')", name: "charge_rules_side_valid"
    add_check_constraint :charge_rules, "basis IN ('turnover','flat','component_sum')",
      name: "charge_rules_basis_valid"
    add_check_constraint :charge_rules,
      "(rate IS NOT NULL) <> (flat_amount IS NOT NULL) OR basis = 'component_sum'",
      name: "charge_rules_one_amount_source"
  end
end
