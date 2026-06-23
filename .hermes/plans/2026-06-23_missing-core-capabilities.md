# PaperExchange Production Readiness Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Close the critical functional gaps that make PaperExchange unsuitable for production paper trading today, starting with the broken risk engine, ledger projections, fill realism, schema integrity, and missing test coverage.

**Architecture:** Preserve the existing exchange-first service boundaries in `app/services`. Make each service independently correct and testable without introducing new frameworks or persistence stores. Keep models thin; keep all domain logic in services.

**Tech Stack:** Ruby 3.3, Rails 8.1, ActiveRecord, Solid Queue (later), Redis Streams (later), RSpec.

---

## Current Blockers (Verified)

1. `Projections::PortfolioProjection` / `PositionProjection` return hardcoded zeros, so risk validators cannot function.
2. `LedgerEntry#balance_after` is never set; account balances are untracked.
3. `FillEngine` slippage does not scale with quantity.
4. `paper_exchange_trades.paper_position_id` is `NOT NULL` but trades are sometimes created before positions.
5. No specs exist; nothing is regression-protected.

---

## Phase 1: Fix Core Trading Integrity

### Task 1: Create Account Balance tracking ledger

**Objective:** Ensure every `ORDER_PLACED` and `TRADE_EXECUTED` ledger event updates account balance state.

**Files:**
- Modify: `app/models/account.rb`
- Modify: `app/services/ledger/ledger.rb`

**Step 1: Add balance fields to Account**

`app/models/account.rb`:

```ruby
class Account < ApplicationRecord
  self.table_name = "accounts"

  validates :account_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :currency, presence: true, inclusion: { in: %w[INR USD] }
  validates :margin, numericality: { greater_than_or_equal_to: 0 }
  validates :current_equity, numericality: { greater_than_or_equal_to: 0 }
  validates :realized_pnl, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :unrealized_pnl, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  after_initialize :set_defaults

  def balance_after
    margin + unrealized_pnl.to_f + realized_pnl.to_f
  end

  private

  def set_defaults
    self.margin          ||= ENV.fetch("PAPER_EXCHANGE_MARGIN", "100000").to_f
    self.current_equity  ||= margin
    self.realized_pnl    ||= 0.0
    self.unrealized_pnl  ||= 0.0
  end
end
```

**Step 2: Run failing migration verification**

Run: `bundle exec rails runner "Account.create!(account_id: 'A1', name: 'Test', currency: 'INR')"`
Expected: FAIL — `unknown attribute 'realized_pnl'`

**Step 3: Add balance columns to accounts table**

Create: `db/migrate/20250623001100_add_pnl_fields_to_accounts.rb`

```ruby
class AddPnlFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    change_table :accounts, bulk: true do |t|
      t.decimal :unrealized_pnl, precision: 18, scale: 4, default: 0.0, null: false
      t.decimal :realized_pnl, precision: 18, scale: 4, default: 0.0, null: false
    end
  end
end
```

**Step 4: Run migration**

Run: `bundle exec rails db:migrate`
Expected: PASS

**Step 5: Update Ledger to refresh account state**

`app/services/ledger/ledger.rb` — add after each `create!`:

```ruby
def self.record_order_placed(account_id:, order:, fill_qty:, fill_price:)
  entry = LedgerEntry.create!(...)
  account = Account.find_by!(account_id: account_id)
  account.update!(
    unrealized_pnl: compute_unrealized_pnl(account_id),
    realized_pnl: compute_realized_pnl(account_id),
    current_equity: account.balance_after
  )
  entry
end

def self.record_trade(account_id:, trade:)
  entry = LedgerEntry.create!(...)
  account = Account.find_by!(account_id: account_id)
  account.update!(
    realized_pnl: compute_realized_pnl(account_id),
    unrealized_pnl: compute_unrealized_pnl(account_id),
    current_equity: account.balance_after
  )
  entry
end

def self.compute_unrealized_pnl(account_id)
  positions = ::PaperExchange::PaperPosition.where(account_id: account_id)
  positions.sum { |p| PaperExchange::Ledger.compute_pnl(p, p.current_price || 0) }
end

def self.compute_realized_pnl(account_id)
  # Sum closed trade PnL from PaperTrades; implement as trades are matched
  ::PaperExchange::PaperTrade.joins(:paper_position)
    .where(paper_exchange_positions: { account_id: account_id })
    .sum("paper_trades.quantity * (paper_trades.price - paper_exchange_positions.avg_price) * CASE WHEN paper_trades.side = 'buy' THEN 1 ELSE -1 END")
end
```

**Step 6: Verify**

Run: `bundle exec rails runner "a=Account.create!(account_id:'Z1',name:'Z',currency:'INR'); puts a.current_equity"`
Expected: `100000.0`

---

### Task 2: Make risk validators money-good

**Objective:** `MaxDrawdownValidator` and `PositionLimitValidator` must read live account state.

**Files:**
- Modify: `app/services/risk/max_drawdown_validator.rb`
- Modify: `app/services/risk/position_limit_validator.rb`

**Step 1: Fix MaxDrawdownValidator**

```ruby
module Risk
  class MaxDrawdownValidator
    MAX_DD = (ENV.fetch("PAPER_EXCHANGE_MAX_DD", "0.10").to_f)

    def evaluate(account_id, signal)
      account = Account.find_by(account_id: account_id)
      return [:passed, self] unless account

      equity = account.current_equity
      max_equity = [equity, account.margin].max
      return [:passed, self] if max_equity <= 0

      dd = (max_equity - equity) / max_equity
      dd <= MAX_DD ? [:passed, self] : [:MAX_DD_REJECTED, self]
    end
  end
end
```

**Step 2: Verify failure mode**

Run: `bundle exec rails runner "account = Account.create!(account_id:'R1',name:'R',currency:'INR',current_equity:80000,margin:100000); res = Risk::MaxDrawdownValidator.new.evaluate('R1', Strategy::Signal.new(account_id:'R1', symbol:'NIFTY', side:'buy', quantity:1)); puts res.first"`
Expected: `:MAX_DD_REJECTED`

---

### Task 3: Fix slippage to scale with quantity

**Objective:** `SlippageEngine#apply` must use the calling `quantity`, not `1`.

**Files:**
- Modify: `app/services/exchange/fill_engine.rb`
- Modify: `app/services/exchange/slippage_engine.rb`

**Step 1: Fix FillEngine fill_price call**

`app/services/exchange/fill_engine.rb` line 11:

```ruby
price = @slippage.fill_price(
  market_snapshot: market_snapshot,
  side: order.side,
  instrument_type: instrument_type,
  quantity: qty
)
```

**Step 2: Fix SlippageEngine to use quantity**

```ruby
def fill_price(market_snapshot:, side:, instrument_type: "EQUITY", quantity: 1)
  raise "Missing bid" if side == "sell" && market_snapshot[:bid].nil?
  raise "Missing ask" if side == "buy" && market_snapshot[:ask].nil?
  base = side == "buy" ? market_snapshot[:ask] : market_snapshot[:bid]
  apply(price: base, quantity: quantity, side: side, instrument_type: instrument_type)
end
```

**Step 3: Verify**

Run: `bundle exec rails runner "s=SlippageEngine.new; puts s.fill_price(market_snapshot:{ask:100,bid:99}, side:'buy', instrument_type:'EQUITY', quantity:500)"`
Expected: value > 100, larger than when quantity=1

---

### Task 4: Make PaperTrade paper_position_id optional

**Objective:** Trades can be recorded before position materialization (during ledger-driven projection).

**Files:**
- Modify: `db/migrate/20250623000300_create_paper_exchange_trades.rb`
- Modify: `app/models/paper_exchange/paper_trade.rb`

**Step 1: Update migration for idempotency**

Change in migration:

```ruby
t.references :paper_order, null: false, foreign_key: { to_table: :paper_exchange_orders }
t.references :paper_position, null: true, foreign_key: { to_table: :paper_exchange_positions }
```

Make the migration reversible by replacing `change` with explicit `up`/`down` or adding `reversible` if you prefer.

**Step 2: Update model**

`app/models/paper_exchange/paper_trade.rb`:

```ruby
belongs_to :paper_order, class_name: "PaperExchange::PaperOrder"
belongs_to :paper_position, class_name: "PaperExchange::PaperPosition", optional: true
```

**Step 3: Handle existing DB**

Run: `bundle exec rails db:migrate:status`
If `20250623000300` is `up`, reset: `bundle exec rails db:drop db:create db:migrate` (safe in dev/test only).

**Step 4: Verify**

Run: `bundle exec rails runner "t = PaperExchange::PaperTrade.create!(paper_order_id: 1, side:'buy', quantity:1, price:100, traded_at:Time.current); puts t.paper_position_id.nil?"`
Expected: `true`

---

### Task 5: Wire PositionProjection.apply_from_ledger

**Objective:** Make position snapshots derive from ledger events instead of being placeholders.

**Files:**
- Modify: `app/services/projections/position_projection.rb`

**Step 1: Implement apply_from_ledger**

```ruby
def apply_from_ledger(ledger_entry)
  return unless ledger_entry.order_id || ledger_entry.trade_id

  trade = ::PaperExchange::PaperTrade.find_by(id: ledger_entry.trade_id)
  return unless trade

  order  = trade.paper_order
  position = ::PaperExchange::PaperPosition.find_or_initialize_by(
    account_id: ledger_entry.account_id,
    symbol: order.symbol,
    side: order.side == "buy" ? "long" : "short"
  )
  position.instrument_type = order.instrument_type
  position.option_type = order.option_type
  position.strike_price = order.strike_price
  position.expiry_date = order.expiry_date

  delta = order.side == "buy" ? trade.quantity : -trade.quantity
  position.quantity = (position.quantity || 0) + delta

  if position.quantity.zero?
    position.current_price = 0
    position.avg_price      = 0
  elsif delta > 0
    total = (position.avg_price || 0) * (position.quantity - delta) + (trade.price * delta)
    position.avg_price = total / position.quantity if position.quantity > 0
  end

  position.current_price = trade.price
  position.save!
end
```

**Step 2: Verify**

Run: `bundle exec rails runner "order=PaperExchange::PaperOrder.create!(account_id:'P1',symbol:'INFY',side:'buy',quantity:10,instrument_type:'EQUITY',order_type:'market',status:'filled'); trade=PaperExchange::PaperTrade.create!(paper_order:order,side:'buy',quantity:10,price:2400,traded_at:Time.current); Ledger.record_trade(account_id:'P1',trade:trade); puts PaperExchange::PaperPosition.last.quantity"`
Expected: `10`

---

## Phase 2: Test Coverage (RSpec)

### Task 6: Add model specs

**Objective:** Ensure validation and callbacks hold after schema changes.

**Test files to create:**
- `spec/models/account_spec.rb`
- `spec/models/paper_exchange/paper_trade_spec.rb`
- `spec/models/paper_exchange/paper_order_spec.rb`

**Pattern for account_spec.rb:**

```ruby
require "rails_helper"

RSpec.describe Account, type: :model do
  it "is valid with valid attributes" do
    account = Account.new(account_id: "T1", name: "Test", currency: "INR")
    expect(account).to be_valid
  end

  it "defaults margin to 100000" do
    account = Account.new(account_id: "T2", name: "Test", currency: "INR")
    expect(account.margin).to eq(100_000)
  end
end
```

Run: `bundle exec rspec spec/models/account_spec.rb -f d`
Expected: green

---

### Task 7: Add service specs

**Objective:** Cover the corrected core services with deterministic tests (no network calls).

**Test files:**
- `spec/services/exchange/order_validator_spec.rb`
- `spec/services/exchange/fill_engine_spec.rb`
- `spec/services/risk/max_drawdown_validator_spec.rb`

**Pattern for fill_engine_spec.rb:**

```ruby
require "rails_helper"

RSpec.describe Exchange::FillEngine do
  let(:slippage) { instance_double(Exchange::SlippageEngine) }
  subject { described_class.new(slippage: slippage) }

  it "delegates price to slippage engine" do
    order = instance_double("PaperExchange::PaperOrder",
      side: "buy",
      remaining_quantity: 10,
      order_type: "market"
    )
    allow(slippage).to receive(:fill_price).and_return(100.25)
    expect(subject.fill(order, market_snapshot: { ask: 100.0, bid: 99.0 }, instrument_type: "EQUITY", quantity: 10).first).to eq(10)
  end
end
```

Run: `bundle exec rspec spec/services/exchange/fill_engine_spec.rb -f d`
Expected: green

---

## Phase 3: Production Hardening

### Task 8: Add idempotency guard to submit_order

**Objective:** Prevent duplicate orders if submit_order is retried by client or job middleware.

**Files:**
- Modify: `app/services/exchange/paper_exchange.rb`
- Modify: `app/models/paper_exchange/paper_order.rb`

Add unique index (pending earlier migration):
`add_index :paper_exchange_orders, [:account_id, :symbol, :status, :placed_at], name: "index_orders_idempotency", unique: true`

Or use `lock!` before create when appropriate.

---

### Task 9: Add AccountLookup / authentication placeholder

**Objective:** Stop trusting `account_id` from client params without domain-boundary enforcement.

**Files:**
- Create: `app/services/auth/account_resolver.rb`
- Modify: `app/controllers/api/base_controller.rb`

```ruby
module Auth
  class AccountResolver
    def self.resolve!(request)
      account_id = request.headers["X-Account-Id"].presence
      raise "Missing X-Account-Id" unless account_id
      Account.find_by!(account_id: account_id)
    end
  end
end
```

---

## Verification Checklist (run after Phase 1)

```bash
bundle exec rails db:drop db:create db:migrate
bundle exec rails runner "puts DhanHQ::Constants::InstrumentType::ALL"
bundle exec rails runner "a=Account.create!(account_id:'V1',name:'V',currency:'INR'); puts a.balance_after"
bundle exec rspec spec/ -f d
```

Expected: all pass, account balance reflects ledger state, risk validators reject real breaches, slippage scales with order size, `paper_position_id` nullable.

---

## Risks, Tradeoffs, and Open Questions

- **Risk:** `compute_realized_pnl` uses a SQL sum that assumes FIFO; if you later support partial closes or short covering, this formula needs a per-lot layer.
- **Risk:** Removing `paper_position_id` nullability lowers referential integrity but matches current asynchronous ledger flow; re-add NOT NULL once projection is proven stable.
- **Tradeoff:** `PortfolioProjection` still lacks a real max-equity curve (only current margin snapshot is tracked). For strict max-drawdown enforcement, store `max_equity` on Account and bump on each equity high-water mark.
- **Open question:** Do you want market data delivery via Redis Streams workers or HTTP polling? The current `TickProcessor` is written assuming streams; workers need to be defined before market feed can run deterministically in paper trading.
- **Open question:** Live broker adapters are deferred ("Next"), but the contract in `Exchange::PaperExchange.submit_order` must remain stable before adapters are written.
