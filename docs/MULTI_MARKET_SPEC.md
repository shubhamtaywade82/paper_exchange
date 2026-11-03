# paper_exchange: multi-market architecture and implementation specification

Status: draft for review. This document changes no code and creates no migrations.
Date: 2026-11-03
Baseline:
- `main` a09a26b (146 commits, no backtesting code)
- PR #52, branch `ccr-4b6aedd2-6l8o0y`, head 38bf993, open
- PR #51, branch `feat/deterministic-tick-backtesting`, head 52e7df9, open

Every factual claim in §2 was read from the repository or the remote branches while writing this document. Claims from the two earlier design documents are checked in §3.

---

## 1. Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | One platform and one accounting core. Market differences live in policies selected from versioned instrument data. No per-market applications. | Ledger, margin, charges and replay must reconcile across markets. |
| D2 | One backtesting namespace, `Backtest`. PR #51's `Backtesting::` primitives move to `Backtest::Tick` when rebased. | Two namespaces for one concept will drift. |
| D3 | Instrument specs (lot, tick, freeze, settlement), trading calendar, charge rules, and market rules are effective-dated rows. No Indian rate, lot size, session time or holiday is a Ruby constant or an ENV default. | A historical trade must be costed and validated with the rules in force on its date. |
| D4 | Money is decimal end to end. `Float` appears only at parsing and presentation boundaries. | Required by the design documents and by accounting correctness. The current code violates this (§2.4). |
| D5 | Time is injected through a `Clock` interface. Replay advances the clock from event time. Live uses wall time through the same interface. Financial code never calls `Time.current`, `Time.now`, `Date.today` or `Date.current`. | Deterministic replay. |
| D6 | Every run declares its execution fidelity: `ohlc_bar`, `trade_tick`, `l1` or `l2`. Tick and L2 runs refuse missing book data and never synthesize depth. | Prevents a bar-based fill from being reported as L2-accurate. |
| D7 | India scope: NSE cash equity (delivery long-only, intraday), index and stock futures (long and short), and index and stock options (buy-to-open only). Commodities, currency, BSE, NCDEX and interest-rate contracts are refused by order rules until their rules are loaded. | Matches the options-buying-only constraint and the data that exists today. |
| D8 | Short options are a non-goal. Selling an option is accepted only to close an existing long. | The stated strategy constraint is options buying only. The second design document proposed enabling short options later. This spec does not, unless you decide otherwise (§14, item 5). |
| D9 | Live matching keeps top-of-book execution until live depth is wired in. Its slippage model is replaced by a bps-of-price model (T0.4). | The current model is not scale-invariant (§2.3). |

---

## 2. Verified baseline

### 2.1 Branches and pull requests

- `main` has 146 commits and no backtesting code.
- `ccr-4b6aedd2-6l8o0y` is `main` plus five commits: the backtest engine, the Ruby pin, the SimpleCov fix, and the refusal and lifecycle specs. PR #52 is open from it.
- `feat/deterministic-tick-backtesting` is `main` plus ten commits (PR #51). It does not contain PR #52's work. PR #51 is open.
- PR #51's nine specs under `spec/services/backtesting/` pass when run in a detached worktree: 9 examples, 0 failures. This ran on Ruby 3.3.6 locally; the repository pins 3.4.12.
- PR #52's description reports 478 examples. This branch runs 534 examples, 0 failures, with line coverage 88.30% (3149/3566).
- Merging both PRs as they stand conflicts in `.github/workflows/ci.yml` and `.ruby-version`:
  - PR #51 pins `ubuntu-24.04` and keeps Ruby 3.4.2.
  - PR #52 keeps `ubuntu-latest` and moves to Ruby 3.4.12. Its CI run 41560816052 passed.
  - `main` pins Ruby 3.4.2 in `.ruby-version` and `ubuntu-latest` in `ci.yml`.

### 2.2 Replay primitives (PR #51)

- `Backtesting::ReplayClock` is monotonic and rejects backwards time. Adequate as written.
- `Backtesting::TickReplay` sorts by (timestamp, sequence, input index). A missing sequence defaults to 0, so ties fall back to input order. Exchange data must carry a sequence (I6).
- `Backtesting::HistoricalOrderBook` supports snapshots only (`replace!`). It has no delta application, no sequence continuity check, and no level removal on zero quantity. Every price and quantity is a `Float`, which breaks the decimal requirement. The walking, VWAP and partial-fill logic is correct for a snapshot.

### 2.3 Live execution

- `Exchange::SlippageEngine#apply` computes `impact = quantity × factor`, clamps it to `max_slippage × price`, and adds it as an absolute amount. The equity factor is 0.0002, so impact is 0.0002 currency per unit regardless of price level. For a 10-unit order, that is 0.4% of price on a 0.50 instrument and 0.000002% on a 100,000 instrument. The model is not scale-invariant (T0.4).
- `Exchange::FillEngine#fill` takes its price from the slippage model unless a price is passed in. It stamps `traded_at` with `Backtest::Session.now`.
- `Exchange::OrderBook` stores depth, and `Exchange::PaperExchange` passes it through (`paper_exchange.rb:368`). Matching does not walk it. Live fills are top-of-book plus the slippage model.
- `Exchange::OrderBook#default_depth` fabricates 100 units on each side. `default_book` falls back to `MarketData::MarkPriceStore` (Redis-backed) with a ±2 bp spread outside the test environment. The fabricated 100-unit depth is therefore reachable from the live path (T0.3).
- `Exchange::MatchingWorker` builds quotes with `mark_price: event.ltp || event.price`. On the live feed, mark and last trade are the same value. The "mark" source used by protections is therefore last trade.
- `ProtectionMonitorJob#fetch_mark_price` (`protection_monitor_job.rb:46–50`) prefers `quote[:mark_price]`, then `quote[:ltp]`, then `MarkPriceStore`, then `position.current_price`. The last fallback is a stored position value with no staleness check. Three price sources are mixed without a declared rule.
- `Exchange::PaperExchange` writes each execution price into `MarketData::MarkPriceStore` (`paper_exchange.rb:145, 238, 355`). A fill changes the mark price that the same process reads.

### 2.4 Money

- 63 lines contain `.to_f` in `app/services/exchange`, `app/services/ledger` and `app/services/risk`. 13 more are in `app/services/backtest`. Counts are from grep line matches.
- `Ledger::Ledger` builds debits and credits with `.to_f` (`ledger.rb:19–32`), and computes balances and PnL with it (`ledger.rb:123, 133, 148`).
- `Exchange::PaperExchange` derives its reference price with `.to_f` (`paper_exchange.rb:93, 101`) and uses `.to_f` for settlement and locked-margin comparisons (`:140, 143, 190, 419`).
- `Exchange::BrokerageCalculator`:
  - reads every rate from ENV in `initialize`;
  - hardcodes the brokerage rate (0.0003), the brokerage floor default (20) and the crypto-perpetual fee (0.0004);
  - computes in `Float`.
  - Its comment says the STT rates were "updated to the NSE schedule effective April 1, 2026". A comment does not make a rate effective-dated. The current rate applies to every trade, past or future.
- `paper_exchange_trades` stores `charges` as jsonb and `total_charges`. Nothing records which rule version produced them.

### 2.5 Time

- 39 wall-clock call sites exist outside `app/services/backtest`. The financial ones:
  - `exchange/order_book.rb:8` (default snapshot timestamp);
  - `exchange/matching_worker.rb:81` (`received_at`);
  - `ledger/reconciler.rb:50` (`occurred_at`);
  - `models/position_protection.rb:94, 100, 129` (`triggered_at`, `cancelled_at`);
  - `jobs/funding_job.rb:73, 109` (`occurred_at`);
  - `jobs/option_expiry_job.rb:31, 36, 45` (`Date.today` and server-zone dates).
- `config/application.rb` sets no `time_zone`, so Rails stores and compares in UTC. Nothing in `app` or `config` references `Asia/Kolkata`. Session hours appear only as a comment in `app/services/backtest/timeframe.rb`.
- `OptionExpiryJob#due?` compares `position.expiry_date < Date.today`. Which calendar day that means depends on the server's zone. Expiry must be evaluated on the exchange's calendar date (T0.2).

### 2.6 Replay seam

- `Backtest::Session` stores `now`, `marks` and `risk_gate?` in `Thread.current`. Services read it implicitly. A replay that depends on thread-local state cannot be reasoned about per event, and two sessions on one thread would interfere. Replace it with an explicit `Replay::Session` argument (T2.2).

### 2.7 Order and fill persistence

- `paper_exchange_orders` has `filled_quantity`, `locked_margin`, a unique index on `(account_id, client_order_id)`, and this status enum: `pending`, `open`, `partially_filled`, `filled`, `cancelled`, `rejected`, `expired`. `PaperExchange::PaperOrder` enforces transitions with `assert_transition!`.
- `paper_exchange_trades` is the fill table. Its columns are `paper_order_id`, `price`, `quantity`, `side`, `charges`, `total_charges`, `fill_type` (default `full`), `traded_at` and `paper_position_id`. It has no execution key, no uniqueness constraint, and no liquidity-source field. Several rows per order are structurally possible. Identity and idempotency are not enforced.

### 2.8 Instruments

- No instrument master table exists. Contract fields (`symbol`, `instrument_type`, `option_type`, `strike_price`, `expiry_date`) are denormalized onto orders, positions and trades.
- `lot_size` appears only on `backtest_runs`, as one value per run. Live order validation has no lot-size or tick-size check for any Indian instrument. The crypto catalogs (Binance USD-M, CoinDCX) do carry lot and tick values.
- `Exchange::DhanInstrumentCatalog` resolves instruments through the `DhanHQ::Models::Instrument` SDK model. It is not backed by versioned local data. Its valid types come from `DhanHQ::Constants::InstrumentType::ALL`.
- Instrument-type strings found by grep: `EQUITY`, `FUTIDX`, `OPTIDX`, `FUTCOM`, `OPTFUT`, `FUTCUR`, `OPTCUR`, `CRYPTO_PERPETUAL`, `CRYPTO_OPTION`. `OPTSTK` appears in `Exchange::SlippageEngine`'s case statement. `FUTSTK` did not appear in the grep and is not assumed to exist.
- `Exchange::OrderValidator` (lines 35–36) rejects EQUITY orders on index underlyings. This rule is kept.

### 2.9 Market data

- `app/services/market_data/providers/` contains `base.rb`, `binance_usdm.rb` and `coindcx_futures.rb`.
- No NSE historical depth or tick provider exists. No Dhan market-data provider exists. Dhan is used only through the instrument SDK.
- `MarketData::MarkPriceStore` and `MarketData::QuoteStore` are Redis-backed. Replay code must not reach them (I8).

### 2.10 Option expiry

- `OptionExpiryJob#settle!` closes an expired option position with a forced reduce-only order at `settlement_value(underlying_price)`. The order is submitted with `internal: true`, which bypasses the margin lock.
- No delivery model exists. Stock options and any physically settled contract therefore have no path. A position in such a contract must be forced out before its delivery cutoff, or the run must fail (§8.4).

---

## 3. Challenges to the two design documents

| Claim | Verdict | Consequence in this spec |
|---|---|---|
| Extend the existing engine with a tick/L2 mode; do not build a second engine. | Agree. | One `Backtest` namespace and one execution gateway. |
| `HistoricalOrderBook` gives VWAP, depth and partial fills. | True for snapshots. | Keep the algorithm. Move it to decimals and add delta updates (T2.1). |
| "Decimal arithmetic without floating-point drift." | Required. The primitive itself violates it. | T0.1 and T2.1. |
| Live slippage is acceptable. | Not claimed in the documents. The code is not scale-invariant. | T0.4. |
| Add short options after margin and expiry are covered. | Conflicts with the options-buying-only constraint. | D8. Non-goal unless you decide otherwise. |
| Long and short futures. | Consistent with the constraint. Needs daily MTM and margin data. | M3. Futures margin is labelled as an estimate until exchange margin data is loaded. |
| NSE equity 09:15–15:30 IST; equity derivatives 09:15–15:40 IST. | Not verified in this session. | Not hardcoded anywhere. Session data comes from `trading_calendar_days` with a `source_ref`. |
| Pin CI to `ubuntu-24.04` if `ubuntu-latest` breaks Ruby 3.4.2. | Not needed on this branch. | PR #52 passed on `ubuntu-latest` with Ruby 3.4.12. Reconcile with PR #51 at rebase (T0.8). |
| Stock derivatives are physically settled; commodity contracts have tender and delivery periods. | Stock F&O physical settlement is the stated rule. Verify the current circular before relying on it. | Forced exit before the delivery cutoff. No delivery simulation in scope. |
| Historical L2 is needed for realistic Indian replay. | True. | No NSE L2 source exists in the repository. This blocks M2 (§14, item 1). |
| Replay must not depend on the live Redis price cache. | True. | Replay reads only the dataset. A missing book refuses the run (I7, I8). |
| Thread-local session context is an acceptable seam. | Not claimed in the documents, but it is implicit global state. | Replace with an explicit `Replay::Session` (T2.2). |

---

## 4. Invariants

These hold in every market and every mode. Each has an enforcing spec.

- **I1 Decimal money.** Every price, quantity, fee, balance, PnL and equity value is a `decimal` column or a `BigDecimal` in memory. `Ledger`, `FillSlice`, `Charges::Calculator` and `Execution::BookWalker` return `BigDecimal`. Enforced by `spec/lint/no_float_money_spec.rb`, which fails on `.to_f` in money files.
- **I2 Single clock.** Financial timestamps come from `Markets::Clock#now`. Replay's clock never moves backwards. Enforced by `spec/lint/no_wall_clock_spec.rb`, which fails on `Time.now`, `Time.current`, `Date.today` or `Date.current` in money-path files.
- **I3 Declared price source.** Every protection carries `trigger_source ∈ {last_trade, bid_ask, mark, index}`. There is no fallback between sources. If the declared source has no value, the trigger is not evaluated, and a `RiskEvent` is recorded.
- **I4 Fill slices are the execution unit.** `order.filled_quantity == Σ slice.quantity`. Average price is `Σ(p·q) / Σq` in decimal. No slice exceeds remaining quantity. Every slice price comes from a level present in the book at that event.
- **I5 Idempotent execution.** `(paper_order_id, execution_key)` is unique. `(account_id, client_order_id)` is unique (existing). Replay event consumption is keyed by `(backtest_dataset_id, symbol, event_type, sequence)`.
- **I6 Sequenced, gap-free book.** Per symbol, sequence strictly increases. A gap, or a duplicate with a different payload, invalidates the affected interval and fails the run. An identical duplicate is a no-op. A missing sequence is a validation error, not a zero.
- **I7 No synthetic liquidity in tick or L2 runs.** A missing book raises `Replay::MissingBook` and fails the run. In live, `default_depth` and the mark-derived fallback book are removed from production code. Test helpers may keep fixtures.
- **I8 Replay isolation.** Replay code never calls `MarketData::MarkPriceStore`, `MarketData::QuoteStore` or any Redis client. Enforced by a spec that stubs those classes to raise.
- **I9 Instrument validity.** An order references the `InstrumentSpec` whose validity window contains the event time. Unknown, expired and not-yet-listed instruments are refused.
- **I10 Session validity.** Entry orders are accepted only inside the segment's session at event time, evaluated in the exchange's zone. Intraday positions are squared off at the configured time in that zone.
- **I11 Versioned charges.** Each trade records `charge_rule_ids`. Charges are computed from rules effective on the trade date in the exchange's zone. A missing rule refuses the order. Legacy trades, with null `charge_rule_ids`, are never recomputed.
- **I12 Live isolation (existing, preserved).** Simulated accounts never enter live jobs. Live cross-account queries keep using `Account.live`. Replay never writes live mark prices.

---

## 5. Data model

All migrations below are proposals. None is applied. The reference-data migration needs the `btree_gist` extension for exclusion constraints. Regenerate `db/schema.rb` after applying.

### 5.1 Reference data

```ruby
# db/migrate/20261103100000_create_market_reference_data.rb
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
              tstzrange(valid_from, COALESCE(valid_until, 'infinity'::timestamptz), '[)') WITH &&
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
      t.string :product, null: false              # e.g. EQUITY_DELIVERY, EQUITY_INTRADAY, FUTIDX, OPTIDX
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
      t.string :product, null: false
      t.string :side, null: false                 # buy | sell | both
      t.string :component, null: false            # brokerage | stt | exchange_txn | sebi | stamp_duty | gst | dp_charge
      t.string :basis, null: false                # turnover | premium | flat | per_order | component_sum
      t.decimal :rate, precision: 20, scale: 10
      t.decimal :flat_amount, precision: 36, scale: 18
      t.decimal :minimum_amount, precision: 36, scale: 18
      t.decimal :maximum_amount, precision: 36, scale: 18
      t.integer :rounding_scale                   # required when rate or flat_amount is used; no default
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
    add_check_constraint :charge_rules,
      "basis IN ('turnover','premium','flat','per_order','component_sum')",
      name: "charge_rules_basis_valid"
    add_check_constraint :charge_rules,
      "(rate IS NOT NULL) <> (flat_amount IS NOT NULL) OR basis = 'component_sum'",
      name: "charge_rules_one_amount_source"
  end
end
```

### 5.2 Execution identity on existing tables

```ruby
# db/migrate/20261103110000_add_execution_identity.rb
class AddExecutionIdentity < ActiveRecord::Migration[8.1]
  def change
    add_column :paper_exchange_trades, :execution_key, :string
    add_column :paper_exchange_trades, :liquidity_source, :string   # top_of_book_model | book_l2 | legacy (backfilled)
    add_column :paper_exchange_trades, :charge_rule_ids, :jsonb, null: false, default: []
    add_index :paper_exchange_trades, %i[paper_order_id execution_key],
      unique: true, where: "execution_key IS NOT NULL",
      name: "index_paper_trades_on_order_execution_key"

    add_reference :paper_exchange_orders, :instrument, foreign_key: true, index: true
  end
end
```

Legacy rows keep a null `execution_key` and a null `liquidity_source`. A later backfill sets `liquidity_source = 'legacy'`. Legacy rows keep their stored `charges` and are never recomputed (I11).

### 5.3 Replay events

```ruby
# db/migrate/20261103120000_create_replay_events.rb
class CreateReplayEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :replay_events do |t|
      t.references :backtest_dataset, null: false, foreign_key: true
      t.string :symbol, null: false
      t.bigint :sequence, null: false              # exchange sequence or update id, per symbol
      t.string :event_type, null: false
      t.datetime :event_at, null: false            # exchange timestamp, UTC
      t.jsonb :payload, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :replay_events, %i[backtest_dataset_id symbol event_type sequence],
      unique: true, name: "index_replay_events_on_identity"
    add_index :replay_events, %i[backtest_dataset_id event_at sequence],
      name: "index_replay_events_on_dataset_time"
    add_check_constraint :replay_events,
      "event_type IN ('snapshot','depth_delta','trade','mark','funding')",
      name: "replay_events_type_valid"
  end
end
```

### 5.4 Run fidelity

```ruby
# db/migrate/20261103130000_add_fidelity_to_backtest_runs.rb
class AddFidelityToBacktestRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :backtest_runs, :fidelity, :string, null: false, default: "ohlc_bar"
    add_check_constraint :backtest_runs,
      "fidelity IN ('ohlc_bar','trade_tick','l1','l2')",
      name: "backtest_runs_fidelity_valid"
  end
end
```

The `default` applies only to existing rows, which are all OHLC runs. New runs must send `fidelity` explicitly. The `RunValidator` requires it for `trade_tick` and `l2`.

### 5.5 Entity relationships

| Entity | Relates to | Keyed by |
|---|---|---|
| `exchanges` | `instruments`, `trading_calendar_days`, `market_rules`, `charge_rules` (nullable) | `code` |
| `instruments` | `instrument_specs` (1:N), `underlying` (self, nullable), `paper_exchange_orders` | `(exchange_id, exchange_segment, security_id)` |
| `instrument_specs` | one instrument, one validity window | `(instrument_id, valid_from)`, no overlap |
| `paper_exchange_orders` | `instruments`, `paper_exchange_trades` (1:N) | `(account_id, client_order_id)` |
| `paper_exchange_trades` | one order, optional position, `charge_rule_ids` | `(paper_order_id, execution_key)` |
| `backtest_datasets` | `replay_events` (1:N), `backtest_runs` | `fingerprint` (existing) |

---

## 6. Service boundaries

```
Clock
  Live                 now -> Time.now.utc
  Replay               now -> event time from the replay cursor; never goes backwards

Markets                (leaf: depends on nothing in accounting)
  Registry             exchange(code) -> Exchange, with time_zone
  Calendar             session_for(exchange:, segment:, at:) -> Session | nil
  InstrumentResolver   resolve(exchange_segment:, security_id:, at:) -> InstrumentVersion
  Rules                value_for(exchange:, product:, rule_key:, on:) -> value | raise MissingRule
  OrderRules           validate!(order, version, session) -> lot, tick, freeze, side, product policy
  Policies::
    EquityDelivery     buy opens; sell limited to owned quantity
    EquityIntraday     squareoff_time from Rules; no carry past it
    FutureContract     long and short; daily MTM; expiry handling per settlement_type
    OptionBuy          buy-to-open only; sell only to close a long

Execution              (depends on Markets, Charges, Clock, Accounting facade)
  Gateway              submit(order, context) -> Result; shared by live and replay
  TopOfBookModel       live only; bps-of-price slippage (replaces SlippageEngine)
  BookWalker           snapshot and delta book; BigDecimal; walks levels
  FillSlice            immutable value object: price, quantity, execution_key, liquidity_source

Charges                (depends on Markets.Rules and ChargeRules)
  Calculator           calculate(trade, rules_on:) -> Breakdown(BigDecimal components, rule_ids)

Settlement             (depends on Execution and Markets)
  Intraday             square-off at Rules.squareoff_time, zone-aware
  Expiry               cash: settle at settlement price; physical: refuse or force exit before cutoff
  Funding              perpetual funding events at their timestamps (existing scope)

Protection
  TriggerEvaluator     evaluates one trigger on its declared trigger_source; no fallback

Replay                 (depends on Execution and Settlement; nothing depends on Replay except runners)
  Session              run_id, clock, book_provider, dataset_fingerprint, fidelity, arrival_latency_ms
  EventLog             ordered, idempotent consumption; gap and conflict detection
  Runner               drives Gateway, Settlement and Protection per event; records equity per event
  MissingBook          error raised when a tick or L2 event has no valid book

Backtest               (existing)
  Engine               OHLC batch driver; continues to work unchanged in behaviour
  RunManager           lifecycle, reset, destroy (existing)
  Results::Recorder    equity, drawdown, exposure, trade metrics (reuses MetricsCalculator)
  (API)                app/controllers/api/backtest_runs_controller.rb, the existing run endpoints
```

Dependency rules:

1. `Markets` depends on nothing in accounting. It is the only place that knows exchange zones, sessions and rules.
2. `Execution` never reads `Replay::Session` directly. The session is passed in as a context value.
3. `Live` workers never call `Replay`. `Replay` never calls live workers.
4. Nothing in `Execution`, `Charges`, `Settlement` or `Protection` calls `Time.current` or `MarkPriceStore`.
5. `Backtest::Session` (thread-local) is removed once `Replay::Session` is in use for OHLC runs too (T2.2).

Method signatures are as written above. Implementation details, including the `Result` type, are part of the ticket that introduces each class.

---

## 7. Product rules

| `instrument_type` | Sides allowed | Opening allowed | Trigger source (proposed default; confirm) | Settlement and expiry | Milestone |
|---|---|---|---|---|---|
| `EQUITY`, delivery | Buy opens. Sell only up to owned quantity. | Yes | `last_trade` | Delivery cycle from `market_rules`. No constant. | M2 |
| `EQUITY`, intraday | Buy and sell, if the symbol is permitted by data. Not assumed. | Yes | `last_trade` | Square off at `squareoff_time` (zone-aware). No carry. | M2 |
| `FUTIDX`, `FUTSTK` | Buy and sell (long and short) | Yes | `last_trade` | Daily MTM. Index: cash at settlement price. Stock: physical, so forced exit before the cutoff. | M3 |
| `OPTIDX`, `OPTSTK` | Buy to open (CE or PE). Sell only to close a long. | Buy only | `last_trade` (premium) | Index: cash at settlement value. Stock: physical, so forced exit before the cutoff. | M3 |
| `FUTCOM`, `OPTFUT` | Refused | No | n/a | Tender and delivery rules not loaded | M5 |
| `FUTCUR`, `OPTCUR` | Refused | No | n/a | Not loaded | M5 |
| Index underlyings as equities | Refused (existing rule) | No | n/a | n/a | existing |
| `CRYPTO_PERPETUAL`, `CRYPTO_OPTION` | Unchanged by this spec, except the trigger-source fix in T0.9 | Unchanged | `mark` for perpetuals (to confirm) | Unchanged | existing |

Notes:

- "Last trade" is the proposed default for India. It is not a trading rule I can verify from the repository. Confirm it (§14, item 6).
- Stock F&O cutoffs are a `market_rules` row (`forced_exit_before_expiry_days`), not a constant.

---

## 8. Execution semantics

### 8.1 Market orders against a book

- Buy walks asks from best to worst. Sell walks bids.
- Each consumed level produces one `FillSlice`. The level's remaining quantity is reduced by the consumed amount. A level at zero is removed.
- VWAP is `Σ(p·q) / Σq` over slices, in decimal, unrounded internally.
- Insufficient depth: the remainder is cancelled with reason `insufficient_depth`. The executed quantity is kept. No fill is invented at a price outside the book. This is the default and needs confirmation (§14, item 7).

### 8.2 Limit orders

- A limit order that crosses the book fills against the crossing levels, as in §8.1, with the limit as a price bound.
- A non-crossing limit order rests. Resting orders consume no book depth until a later event crosses them.
- In `l2` fidelity, a resting limit fills only on a trade print through its price. The model has no queue position. The run manifest records `queue_model: none`.
- Price improvement is recorded as the difference between the limit and the fill price, in decimal.

### 8.3 Latency

- An order becomes eligible at the first market event at or after `arrival_at = submitted_at + arrival_latency_ms`.
- `arrival_latency_ms` is a required run field. It has no default.

### 8.4 Expiry, squareoff and physical contracts

- Intraday positions are squared off at the `squareoff_time` from `market_rules`, evaluated in the exchange zone.
- A cash-settled expiry closes the position at the settlement price with a reduce-only order, as `OptionExpiryJob` does today.
- A physically settled contract that is still open at its forced-exit cutoff is closed with a reduce-only order. If no executable book exists for that event, the run fails. No delivery is simulated.

### 8.5 Order state machine

| From | Event | To | Notes |
|---|---|---|---|
| `pending` | Validation fails | `rejected` | Reason code recorded. Consumes no depth. |
| `pending` | Arrival time reached and validation passes | `open` | |
| `open` | Slice executed, remaining > 0 | `partially_filled` | |
| `open`, `partially_filled` | Slice executed, remaining = 0 | `filled` | |
| `open` (market) | Book exhausted | `cancelled` | Reason `insufficient_depth`. Executed quantity kept. |
| `partially_filled` | Cancel request | `cancelled` | Executed quantity kept. |
| `open`, `partially_filled` | Expiry or session end | `expired` | |
| Any terminal state | Any event | No transition | Logged, not applied. |

Transitions are enforced by `assert_transition!` as today. Each transition and each slice is written in one transaction together with its ledger entries (T3.3).

---

## 9. Money and charges

- A rule row applies to a trade when `product`, `component` and `side` match and the trade date falls in `[effective_from, effective_until]` in the exchange zone. The exclusion constraint guarantees at most one row.
- A missing rule refuses the order with `MissingRule`. There is no default rate.
- Basis handling:
  - `turnover`: rate × traded value, computed per slice.
  - `premium`: rate × premium value, computed per slice.
  - `flat` and `per_order`: applied once, on the order's first slice.
  - `component_sum`: rate × the sum of `base_components`, applied after those components.
- Rounding uses the rule's `rounding_scale`. The rounding mode is fixed in code and documented in the rule's `source_ref`. Scale and mode are inputs (§14, item 2).
- Minimums and maximums are rule fields, not code constants.
- The `Breakdown` written to `paper_exchange_trades.charges` keeps every component, its basis, and its rule id.

---

## 10. Milestones and tickets

Priority is strict: M0 is a prerequisite for every other milestone, and M2 cannot be validated against NSE until the data in §14 exists.

### M0. Money-path correctness (all markets)

| ID | Work | Touches | Depends | Done when |
|---|---|---|---|---|
| T0.1 | Replace `.to_f` in money paths with `BigDecimal`. Keep `Float` only at API serialization. | `ledger/ledger.rb`, `exchange/paper_exchange.rb`, `exchange/fill_engine.rb`, `exchange/brokerage_calculator.rb`, `exchange/margin_engine.rb`, `risk/*` | none | I1 spec passes. `no_float_money_spec` lists zero files. |
| T0.2 | Inject `Markets::Clock` in place of `Time.current`, `Time.now` and `Date.today` in money paths. Evaluate option expiry on the exchange calendar date. | `exchange/order_book.rb:8`, `exchange/matching_worker.rb:81`, `ledger/reconciler.rb:50`, `models/position_protection.rb`, `jobs/funding_job.rb`, `jobs/option_expiry_job.rb` | none | I2 spec passes. Expiry spec covers a UTC-date/IST-date boundary. |
| T0.3 | Remove fabricated depth from live. `default_depth` and mark-derived books are test-only. Live with no snapshot raises. | `exchange/order_book.rb` | T0.2 | Live spec: no snapshot → refused, no fill. |
| T0.4 | Replace `quantity × factor` with a bps-of-price impact that is scale-invariant. | `exchange/slippage_engine.rb` | T0.1 | Same bps impact for prices 0.5 and 100,000. |
| T0.5 | Charge rules as rows. `BrokerageCalculator` becomes `Charges::Calculator` reading `charge_rules`. Remove ENV rates. Legacy trades keep stored charges. | `exchange/brokerage_calculator.rb`, migration §5.1, §5.2 | T0.1 | I11 spec passes. Missing rule refuses. |
| T0.6 | Trade identity: `execution_key` unique per order. Idempotent submission. | migration §5.2, `exchange/fill_engine.rb`, `exchange/paper_exchange.rb` | T0.1 | I5 spec passes. Duplicate submission and duplicate slice both no-op. |
| T0.7 | Keep `Backtest::Session` working for OHLC. Stop reading it from money code once T2.2 lands. | `backtest/session.rb`, `exchange/fill_engine.rb` | T0.2 | OHLC regression suite unchanged. |
| T0.8 | Reconcile PR #51 and PR #52 at rebase: one namespace (D2), one CI runner setting, one Ruby pin. | `.github/workflows/ci.yml`, `.ruby-version`, `app/services/backtesting/*` | PR #52 merged first | `main` CI green on the reconciled branch. |
| T0.9 | Declared trigger source. Replace `ProtectionMonitorJob#fetch_mark_price` fallback chain with `Protection::TriggerEvaluator`. Stop writing fill prices into `MarkPriceStore` (`paper_exchange.rb:145, 238, 355`). | `jobs/protection_monitor_job.rb`, `models/position_protection.rb`, `exchange/paper_exchange.rb`, `exchange/matching_worker.rb` | T0.2 | I3 spec passes. Missing source records a `RiskEvent` and does not trigger. |

### M1. Reference data and order rules

| ID | Work | Touches | Depends | Done when |
|---|---|---|---|---|
| T1.1 | Migrations §5.1 (exchanges, instruments, instrument_specs, calendar, market_rules, charge_rules). | `db/migrate/*`, `db/schema.rb` | M0 | Migration up and down clean. Exclusion constraints specced. |
| T1.2 | Importers for instrument master and calendar. Source files are inputs (§14). Each row stores `source` and `source_checksum`. | `app/services/markets/importers/*` (new) | T1.1, §14 | Re-import of identical file is a no-op. Changed file creates new versions only. |
| T1.3 | `InstrumentResolver` and `OrderRules`. Lot multiple, tick alignment, freeze quantity, product policy. | `app/services/markets/*` (new), `exchange/order_validator.rb` | T1.1 | Lot, tick and freeze specs pass. |
| T1.4 | `Calendar#session_for` with zone-aware session windows. | `app/services/markets/calendar.rb` (new) | T1.1 | Weekend, holiday, special session and expiry-day cutoff specs pass. |
| T1.5 | Refuse orders on instruments outside their validity window. | `markets/instrument_resolver.rb`, `exchange/paper_exchange.rb` | T1.3 | I9 spec passes. |

### M2. L2 replay for NSE cash equity

| ID | Work | Touches | Depends | Done when |
|---|---|---|---|---|
| T2.1 | Port PR #51's primitives to `Backtest::Tick`. Decimal arithmetic. Add delta application, sequence continuity, crossed-book checks on every delta, and level removal at zero. | `app/services/backtest/tick/{replay_clock,tick_replay,historical_order_book}.rb` (new, from PR #51) | T0.8, T0.1 | Tick spec suite passes, decimal-typed. Delta spec passes. |
| T2.2 | `Replay::Session`, `Replay::EventLog`, `Replay::Runner`. Explicit context, no thread-local reads. | `app/services/backtest/replay/*` (new) | T2.1 | I6, I7, I8 specs pass. |
| T2.3 | `Execution::Gateway` for replay. Slices, state machine, latency. | `app/services/execution/*` (new) | T2.2, T1.3, T0.5 | §8 specs pass. Ledger reconciles to slices. |
| T2.4 | Dataset loader writing `replay_events`, with checksum and gap report. | migration §5.3, `app/services/backtest/dataset_manager.rb` | T2.1 | Gap and conflict cases refuse the dataset. |
| T2.5 | Run configuration: `fidelity`, `arrival_latency_ms`, `queue_model`, manifest. | migration §5.4, `backtest/run_validator.rb` | T2.2 | Missing `arrival_latency_ms` rejected. Manifest includes checksum and config hash. |

### M3. Futures and long options

| ID | Work | Touches | Depends | Done when |
|---|---|---|---|---|
| T3.1 | `Policies::FutureContract` and `Policies::OptionBuy`. Sell-to-open on options refused. | `app/services/markets/policies/*` (new) | M1 | D8 specs pass. |
| T3.2 | Daily MTM for futures, from settlement data. Margin labelled `estimated` until exchange margin is loaded. | `app/services/settlement/*` (new), `risk/margin_validator.rb` | T3.1, §14 | MTM reconciles to ledger. Estimated flag present on every margin figure. |
| T3.3 | Expiry settlement for cash-settled index contracts; forced exit for stock contracts before cutoff. Replaces `OptionExpiryJob`'s date check. | `jobs/option_expiry_job.rb`, `settlement/expiry.rb` (new) | T1.4, T0.2 | §8.4 specs pass. Physical contract with no book → run fails. |
| T3.4 | Intraday squareoff from `market_rules`. | `settlement/intraday.rb` (new) | T1.4 | Squareoff at configured zone time; no overnight carry. |

### M4. Equity cash, delivery and intraday

| ID | Work | Touches | Depends | Done when |
|---|---|---|---|---|
| T4.1 | `Policies::EquityDelivery`: buy opens, sell limited to owned quantity. | `markets/policies/equity_delivery.rb` (new) | M1 | Long-only specs pass. |
| T4.2 | `Policies::EquityIntraday`: permitted-symbol check from data. | `markets/policies/equity_intraday.rb` (new) | T3.4 | Permitted-symbol and squareoff specs pass. |

### M5. Deferred

Commodities (`FUTCOM`, `OPTFUT`), currency (`FUTCUR`, `OPTCUR`), BSE, NCDEX and interest-rate products. Each needs its own rule rows, delivery and tender data, and validation before it is enabled. Until then they are refused by `OrderRules`.

### M6. Results across markets

| ID | Work | Touches | Depends | Done when |
|---|---|---|---|---|
| T6.1 | Results recorder writes realized and unrealized PnL, fees, funding, drawdown, exposure and position history per run, with the manifest. | `backtest/results/recorder.rb` (new), `backtest/metrics_calculator.rb` | M2 | PnL reconciles to ledger in every mode. |
| T6.2 | Cross-run comparison refuses runs with different fidelity unless the caller asks explicitly. | `backtest/runs_controller` | T6.1 | Comparison spec passes. |

---

## 11. RSpec acceptance by milestone

Spec locations follow the repository's existing convention: `spec/services/backtest/...` and `spec/services/markets/...`. Lint guards live under `spec/lint/`.

### M0

- `spec/lint/no_float_money_spec.rb`: no `.to_f` in money files (I1).
- `spec/lint/no_wall_clock_spec.rb`: no wall-clock calls in money files (I2).
- `spec/services/exchange/slippage_engine_spec.rb`: bps impact is scale-invariant across prices 0.5 and 100,000; impact never exceeds the cap.
- `spec/services/exchange/order_book_spec.rb`: live with no snapshot refuses and does not fill; no 100-unit fabricated depth outside test.
- `spec/services/charges/calculator_spec.rb`:
  - each component uses its effective-dated rule;
  - a rule change on a later date does not change an earlier trade;
  - a missing rule raises `MissingRule`;
  - legacy trades keep their stored charges;
  - rounding uses the rule's scale.
- `spec/services/exchange/trade_identity_spec.rb`: duplicate `execution_key` is a no-op; duplicate submission creates no second ledger entry (I5).
- `spec/services/protection/trigger_evaluator_spec.rb`:
  - each `trigger_source` evaluated only from its own source;
  - missing source records a `RiskEvent` and does not trigger;
  - stop-loss and take-profit trigger at the declared source's price;
  - a fill does not change `MarkPriceStore` (I3, T0.9).
- `spec/services/exchange/paper_exchange_rollback_spec.rb`: a failed ledger write rolls back the fill slice and the order transition together.

### M1

- `spec/services/markets/instrument_resolver_spec.rb`: resolves the version valid at event time; refuses expired and not-yet-listed instruments; exclusion constraint rejects overlapping specs (I9).
- `spec/services/markets/order_rules_spec.rb`:
  - quantity not a multiple of `lot_size` is refused;
  - price off `tick_size` is refused;
  - quantity above `freeze_quantity` is refused;
  - EQUITY on an index underlying is refused;
  - a non-lot-size multiple for an option is refused.
- `spec/services/markets/calendar_spec.rb`: weekend, holiday, special session, expiry-day cutoff, and zone boundary (IST date vs UTC date).
- `spec/services/markets/importers/instrument_import_spec.rb`: identical re-import is a no-op; changed row creates a new version with a new checksum.

### M2

- `spec/services/backtest/tick/historical_order_book_spec.rb`:
  - invalid price, zero quantity, negative quantity and duplicate levels are refused;
  - buy walks asks and sell walks bids;
  - VWAP across multiple levels is exact with no float drift;
  - insufficient depth yields a partial fill with the remainder reported;
  - a second order sees consumed depth;
  - a zero-quantity level is removed;
  - a delta that crosses the book is refused;
  - a delta on a missing level is refused.
- `spec/services/backtest/tick/tick_replay_spec.rb`: missing sequence is a validation error; identical timestamp and sequence with different payloads is refused; identical duplicate is a no-op.
- `spec/services/backtest/replay/event_log_spec.rb`: sequence gap invalidates the interval and fails the run (I6).
- `spec/services/backtest/replay/missing_book_spec.rb`: a tick or L2 event with no book raises `MissingBook`, and the run is marked failed (I7).
- `spec/services/backtest/replay/redis_blindness_spec.rb`: with `MarkPriceStore` and `QuoteStore` stubbed to raise, a full replay still completes (I8).
- `spec/services/execution/gateway_replay_spec.rb`:
  - a market buy of 4 against 2@100.00, 3@100.10 yields VWAP 100.05 and leaves 1 at level 2 in the next order;
  - a limit that does not cross rests and consumes no depth;
  - a resting limit fills only on a trade through its price;
  - a market order against exhausted depth is cancelled with `insufficient_depth` and keeps its executed quantity;
  - an order that arrives before its `arrival_at` is not eligible.
- `spec/services/backtest/run_validator_spec.rb` (extended): `trade_tick` and `l2` runs without `arrival_latency_ms` are refused; manifest includes dataset checksum and config hash.
- `spec/integration/deterministic_replay_spec.rb` (release gate, §12).

### M3

- `spec/services/markets/policies/future_contract_spec.rb`: long and short futures open; MTM posts daily; index contract settles in cash; stock contract is force-exited before cutoff.
- `spec/services/markets/policies/option_buy_spec.rb`: buy-to-open CE and PE accepted; sell-to-open refused; sell-to-close a long accepted; premium debited with charges.
- `spec/services/settlement/expiry_spec.rb`:
  - expiry on the exchange calendar date, not the server date;
  - physical contract with no executable book fails the run;
  - forced exit before cutoff is reduce-only.
- `spec/services/risk/margin_estimated_spec.rb`: every futures margin figure carries `estimated: true` until exchange margin data is loaded.

### M4

- `spec/services/markets/policies/equity_delivery_spec.rb`: buy within available funds fills; sell beyond owned quantity is refused; partial exit reduces position and cost basis.
- `spec/services/markets/policies/equity_intraday_spec.rb`: entry fills; squareoff at configured zone time closes position; overnight carry refused; non-permitted symbol refused.

### M6

- `spec/services/backtest/results/recorder_spec.rb`: realized PnL, fees, funding, drawdown, exposure and position history reconcile to the ledger for each fidelity.

---

## 12. Verification and release gates

Commands, as in the existing CI:

```bash
RAILS_ENV=test bin/rails db:test:prepare
bundle exec ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(ARGV)' spec
bin/rubocop -f github
bin/brakeman --no-pager
bin/bundler-audit
```

The local invocation above is needed because `bundle exec rspec` does not resolve here. CI uses `bin/rails db:test:prepare spec`.

Additional gates:

| Check | Acceptance |
|---|---|
| Migrations | Up and down clean on an empty database and on a populated one. Exclusion constraints reject overlapping rows. |
| PostgreSQL integration | Unique execution keys and no-overlap constraints verified against a real database, not stubs. |
| Redis integration | `redis_blindness_spec` passes (I8). |
| Deterministic parity | Same dataset checksum and config hash produce identical slices, trades, ledger rows and equity series. |
| Live isolation | No simulated account is picked up by live jobs. Covered by existing `live_isolation` spec and extended in M0. |
| OHLC regression | Existing backtest suite passes unchanged. |

**Mandatory release gate.** The regression test below is adapted to the names in this spec:

```ruby
it "produces identical execution results for identical replay inputs" do
  first  = run_tick_replay(dataset: dataset, configuration: configuration)
  second = run_tick_replay(dataset: dataset, configuration: configuration)

  expect(second.slices).to eq(first.slices)
  expect(second.trades).to eq(first.trades)
  expect(second.ledger_rows).to eq(first.ledger_rows)
  expect(second.equity_curve).to eq(first.equity_curve)
  expect(second.final_balance).to eq(first.final_balance)
end
```

`run_tick_replay` is a spec helper that does not exist yet. It is introduced with T2.3, together with the replay gateway it drives.

Comparisons include timestamps, quantities, prices, fees, rule ids, ordering and sequence. Final PnL alone does not count.

---

## 13. Known limits and fidelity labels

| Fidelity | Data | What the result may claim | What it may not claim |
|---|---|---|---|
| `ohlc_bar` | OHLCV | Approximate fills at bar open with a model slippage | Liquidity, depth or queue behaviour |
| `trade_tick` | Trade prints | Tick-driven fills against approximate liquidity | Depth-accurate fills |
| `l1` | Best bid and ask | Spread-aware execution | Market impact |
| `l2` | Depth snapshots and deltas, sequenced | Depth-aware execution with no queue model (`queue_model: none`) | Queue position, hidden liquidity |

Other known limits:

- Replay assumes a single account's orders do not affect the book. Market impact on the historical book is not modelled beyond consumption.
- Margin for futures is an estimate until exchange margin data is loaded. Every figure says so.
- Stock derivatives are not delivered. Positions must be exited before the cutoff or the run fails.
- Rounding of charges depends on the rule's scale and mode. Both are inputs (§14).

---

## 14. Required inputs before implementation

Implementation of the affected milestones cannot be validated without these. I will not supply them from memory.

1. **Historical NSE L2 or tick data.** The vendor, the file format, depth levels, and whether sequence or update identifiers are present. The repository has no NSE depth provider. Without this, M2 can run only as `ohlc_bar` or `trade_tick` labelled data. Nothing in `app/services/market_data/providers` covers NSE.
2. **Charge schedules with effective dates.** Your broker plan's brokerage terms, and the statutory and exchange rates for each financial year, with a source reference per row. Also the rounding scale and mode. The current ENV defaults are not a source.
3. **Trading calendar.** The exchange holiday list and special-session list per segment, with source references, for each year needed.
4. **Instrument master source.** Which file or API is the source of truth, and whether daily snapshots must be stored. Dhan SDK lookups are not versioned.
5. **Strategy scope.** Confirm options are buy-to-open only across the platform (D8), and that long and short futures are in scope (D7). Confirm short intraday equity is out of scope unless a permitted-symbol list is supplied.
6. **Trigger source defaults.** Confirm `last_trade` for India equity, futures and options, and `mark` for crypto perpetuals. The repository currently mixes these (§2.3).
7. **Market-order partial-fill policy.** Confirm that the unfilled remainder of a market order is cancelled, not rested (§8.1).
8. **Margin source.** Exchange margin files for futures (SPAN-style data), or confirmation that estimated margin, labelled `estimated`, is acceptable for M3.
9. **Arrival latency.** The value to use for `arrival_latency_ms` in replay runs. There is no default.

---

## 15. Non-goals

- Short options, naked or otherwise (D8).
- Physical delivery simulation for stock derivatives.
- Commodity, currency, BSE, NCDEX and interest-rate contracts before M5.
- Queue-position modelling in L2.
- Changing live matching to walk depth. That follows once live L2 feed quality is established.
- Changing the Rails time zone. Storage stays UTC. Session logic uses each exchange's zone.
- Any change to `crypto-trading-agent`.

---

## 16. Implementation status

Branch `ccr-4b6aedd2-6l8o0y`. Suite: 688 examples, 0 failures; RuboCop, Brakeman and bundler-audit clean.

### Done

| Item | Where |
|---|---|
| Options buy-only: a non-reduce_only sell on OPTIDX, OPTSTK, OPTFUT or OPTCUR is refused | `Exchange::OrderValidator` (4161e02) |
| Cash equity cannot be sold short; checked under the account lock with open sells reserved | `Exchange::PaperExchange#assert_equity_holdings!` (4161e02) |
| Backtests refuse `allow_short` on cash equity | `Backtest::Strategies::SmaCross` (4161e02) |
| Decimal money: ledger posting and PnL, prices, notional, margin, liquidation | `Ledger::Ledger`, `PaperExchange`, `MarginValidator`, `LiquidationCalculator`, `MarginEngine` (2b3b24b) |
| Ratchet on the float conversions still in money code | `spec/lint/money_paths_spec.rb` |
| One clock; expiry decided on the exchange date (Asia/Kolkata) | `Clock` (2b3b24b) |
| No fabricated depth; mark-derived books labelled `:mark_derived` | `Exchange::OrderBook` (2b3b24b) |
| Scale-invariant slippage (fraction of price) | `Exchange::SlippageEngine` (2b3b24b) |
| India charges from effective-dated `charge_rules`; a missing rule raises; legacy values installed | `Charges::Calculator`, `Charges::LegacyRules`, `charges:install_legacy_rules` (2b3b24b) |
| Fill identity: `execution_key` unique per order, rule ids, liquidity source | `Exchange::FillEngine` (2b3b24b) |
| Protections declare a trigger source; no fallback; unavailable prices recorded | `ProtectionMonitorJob`, `PositionProtection` (2b3b24b) |
| Fills no longer write the mark-price cache | `Exchange::PaperExchange` (2b3b24b) |
| Reference-data migrations: exchanges, instruments, instrument specs, calendar, market rules, charge rules | `db/migrate/20261103100000_*` (2b3b24b) |
| Order rules: unsupported types refused; instrument, lot, freeze, tick, validity and session checks when enforced | `Markets::OrderRules`, `Markets::Enforcement` (822a71c) |
| Stock options are not cash-settled; one risk event per position | `OptionExpiryJob` (822a71c) |
| L2 book with decimal arithmetic and depth deltas; ordered events; contiguous sequences | `Backtest::Tick` (822a71c) |
| Market orders priced against the book, one fill per consumed level | `Backtest::Tick::Gateway` (822a71c) |
| Runs declare fidelity; only `ohlc_bar` is executable | `Backtest::RunValidator` (this commit) |

### Partial

- **T0.1 float money.** About 33 `.to_f` occurrences remain in 11 money files. They are the matching comparisons against float quotes, liquidation comparisons, and the trailing-stop arithmetic. The ratchet stops them growing.
- **T0.5 charges.** Crypto charges still come from ENV. The legacy India rows are unverified and carry source `legacy:`. They are in force for every date, as the code always applied them.
- **T2.2 to T2.3 replay.** `EventLog` and `TickReplay` are not driven by a run loop. The gateway handles market orders only, and it does not yet update positions, margin or the ledger.
- **M3 settlement.** Stock options are gated. Forced exit before a physical expiry is not built.

### Not done, and blocked

| Item | Blocked on |
|---|---|
| T1.2 instrument master importer | The instrument master source (§14, item 4) |
| T1.4 trading-calendar rows | The calendar source (§14, item 3) |
| T2.4 NSE depth dataset loader; replay run loop; replay accounting | NSE L2 or tick data (§14, item 1) |
| T3.2 daily futures mark-to-market; estimated margin flag | Settlement price and margin sources (§14, items 6 and 8) |
| T3.3 forced exit before physical expiry | Cutoff rules, loaded into `market_rules` |
| T3.4 and M4 intraday square-off and intraday policy | A product flag on orders and positions; none exists |
| T0.8 close PR #51 | Your decision. Its primitives now live in `Backtest::Tick` on this branch |
| M6 results recorder | Not started |
| T7.4 funding and T7.5 option expiry in backtests | Not started |
| T6.43 CI coverage gate | A threshold decision |
| T0.7 remove the thread-local `Backtest::Session` | Still used by the mark store and the risk gate |

### Decisions taken in this change

1. Option writing is refused for every option type, not only crypto (D8).
2. Cash-equity sells are limited to holdings, and equity shorts are refused in backtests as well as live.
3. A `mark` protection reads the quote's mark, then the mark store. Those are the same declared source. Last trade and bid/ask never stand in for it.
4. Stock options are never cash-settled. Their positions stay open and get a risk event.
5. The legacy charge rows have no effective date. They are in force for every date, which is the behaviour the code always had.
6. Market-rule enforcement is off until `PAPER_EXCHANGE_MARKET_RULES=enforce` is set. The always-on refusals of unsupported types do not depend on it.
7. A market order that exhausts depth reports its remainder. Cancelling the remainder as `insufficient_depth` is not yet wired to order status.
8. `db/schema.rb` was regenerated by the dumper, which drops the hand-written comments. The migrations keep the design notes.
9. Pre-existing: `spec/services/exchange/position_manager_concurrency_spec.rb` commits rows outside a transaction. The charge-rule hook clears the table before each example for that reason.
