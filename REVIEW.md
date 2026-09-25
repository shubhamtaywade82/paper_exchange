# Code Review: `paper_exchange`

**Reviewed with:** the [`ruby-agent-skills`](https://github.com/shubhamtaywade82/ruby-agent-skills) agent skill pack (Iteration 79) — `agent-workflow`, `rails-best-practices`, `rails-security-engineering`, `rails-test-engineering`, `ruby-concurrency`, `rails-deployment` skills, plus pattern guidance from `patterns/rails/` (transaction-lock-boundary, idempotent-job, security-boundary-review, n-plus-one-review).
**Scope:** full audit across all six AGENTS.md review dimensions — correctness, simplicity, architecture, security, performance, scope. Every Ruby file under `app/` (~45 files), config, schema, migrations, and the spec suite were read. No specs or scanners were executed (no Ruby runtime in the review environment); all findings are from code reading, with file:line evidence.
**Severity model:** **MUST** (ship-blocking: data integrity, security, or a broken endpoint) / **SHOULD** (real defect or debt that will bite) / **NICE** (polish).

---

## Verdict

This is a **genuinely well-engineered simulator with excellent ledger discipline and commentary culture** — and it has **seven must-fix issues**: a committed master key that decrypts your credentials file, a fully unauthenticated API whose mark-price endpoint can force-liquidate any account at a price of your choosing, two money-integrity races in the position/margin path, a fail-open risk gate whose rejection events are silently rolled back, a liquidation path that can report success while the position stays open, and one endpoint that can never succeed. None of these are architectural: the bones are good, and every MUST has a small, targeted fix.

---

## System overview (for context)

Rails 8.1 API-only app. Agent-driven paper broker: the trading agent owns market data and pushes `execution_price` per order, bulk mark prices (`POST /api/mark_prices`), and funding settlements (`POST /api/funding_events`). Order flow: `PaperExchange.submit_order` → validate → (optional margin lock + risk gate) → match against a snapshot book → fill → `PositionManager.apply!` → `MarginEngine.sync_position!` → ledger entries. Wallet movements go exclusively through `Ledger::MarginLedger` under `SELECT ... FOR UPDATE`, paired with append-only `LedgerEntry` rows; a boot-time `Ledger::Reconciler` rebuilds wallet state from the ledger and re-arms the in-memory liquidation cache. Liquidation is two-phase: an in-process cache check on every mark-price push enqueues `LiquidationJob`, which re-checks against the DB and force-closes with `internal: true, reduce_only: true` (skipping the margin gate that would deadlock on an underwater account).

---

## MUST FIX

### M1. The master key committed in `.env.example` (and hardcoded in `docker-compose.yml`) decrypts `config/credentials.yml.enc`

**Evidence — verified, not speculative.** `.env.example:4` ships `RAILS_MASTER_KEY=f92a…713a (redacted — full value in git history; see audit M1)`. `docker-compose.yml` hardcodes the same value as the *default fallback* (`RAILS_MASTER_KEY: ${RAILS_MASTER_KEY:-f92a…713a (redacted — full value in git history; see audit M1)}`), so a `docker compose up` without regenerating works — which strongly implies it's the real key. I decrypted the committed `config/credentials.yml.enc` with that key (AES-256-GCM, standard Rails layout): it succeeds and yields the `secret_key_base` (`d5d5…(redacted)`). Today the file only contains `secret_key_base` and commented placeholders, so the *current* blast radius is limited — but the moment anyone adds a Dhan access token or Binance key to credentials, it is public. The key also exists in git history, so rotation must include history considerations (or at minimum, treat the repo as having leaked the secret forever).

**Fix (do this today, in order):**
1. `bin/rails credentials:edit` on a clean checkout → replace `secret_key_base` with `openssl rand -hex 64`; remove the old value.
2. Generate a new master key (`bin/rails credentials:reset` or manually: new 32-byte hex key + re-encrypted file), keep it *only* in uncommitted `.env` / Kamal secrets.
3. Replace `.env.example:4` with a placeholder (`RAILS_MASTER_KEY=replace-me`) and delete the `:-default` fallback in `docker-compose.yml` so a missing key fails loudly at boot instead of silently using the leaked one.
4. Rotate `SECRET_KEY_BASE` in `.env.example` to a placeholder too — a real-looking committed value invites copy-paste deployment.
5. Add a CI guard: `grep -rE "^[A-F0-9]{64}$" .env.example docker-compose.yml` fails the build (secret-pattern check), or run a secret scanner (gitleaks) in the workflow next to brakeman.

### M2. No authentication on any endpoint — account identity is an unauthenticated header, so the whole API is one trust domain

**Evidence.** `app/controllers/api/base_controller.rb:7-11` resolves the acting account purely from `X-Account-Id` / `X-API-Key` / `params[:account_id]`, defaulting to `"default"`. There is no token verification anywhere (`ApplicationController < ActionController::API` is empty). Anyone who can reach the port can: read any account's ledger and positions, submit/cancel orders on any account, push mark prices that trigger liquidations (see M3), post funding events, and — in dev/test — `POST /api/account/reset` wipes any account. `config/initializers/cors.rb:10` additionally allows `origins "*"` with all methods. The README's "Production-grade" claim plus Kamal/Docker deploy configs imply network exposure well beyond localhost.

**Impact.** For a single-user paper broker on a loopback interface this is a deliberate trade-off — but nothing enforces that boundary, and `X-API-Key` masquerading as auth is a trap for whoever deploys this next. The `rails-security-engineering` skill's first rule applies: *place authentication at the boundary that owns the security decision* — right now no boundary owns it.

**Fix.** Pick the smallest option consistent with the deployment story and make it explicit:
- **Minimum (single-operator deployment):** a shared bearer token — `X-API-Key` must equal `ENV["PAPER_EXCHANGE_API_KEY"]`, checked in `BaseController` with a `before_action` returning 401; fail boot if unset in production. Keep account resolution as-is (account switching *within* the trusted operator).
- **If multi-account ever matters:** real per-account API keys (hashed `api_key` column on `Account`, constant-time compare), and scope every query by the key's account — which also removes the "default" account fallback.
- Either way, tighten CORS to the agent's origin (or drop rack-cors entirely for a non-browser API), and document the trust model in the README next to the "Crypto market data ownership" section, which already explains this style of boundary well.

### M3. Mark-price and funding inputs are unvalidated — a garbage price becomes `0.0` and mass-liquidates every long position on the symbol

**Evidence.** `app/controllers/api/mark_prices_controller.rb:17-23` takes arbitrary `params[:prices]` values and calls `MarketData::MarkPriceStore.set(symbol, price)` — `"abc".to_f == 0.0` (`mark_price_store.rb:17`). `check_symbol!` then runs `price <= liquidation_price` for longs (`risk/liquidation_engine.rb:34`), which is trivially true at `0.0` → every leveraged long on that symbol gets a `LiquidationJob` at price 0, and `LiquidationJob` re-checks `position.liquidated?(0.0)` (`paper_position.rb:46-49`) → still true → the position is force-closed at a zero-ish fill. One malformed push (`""`, `"null"`, a number-as-object from a buggy agent) wipes simulated accounts. Same class of issue in `funding_events_controller.rb`: `funding_rate.to_f` is unbounded and unvalidated, so a fat-fingered `1.0` (100% per 8h) or `1e9` silently posts a monstrous fee, and an unparseable `funding_time` casts to `nil`, silently bypassing the `(paper_position_id, funding_time)` dedup index (which is partial: `WHERE funding_time IS NOT NULL`).

**Fix.** Validate at the trust boundary, before anything touches hot state:
```ruby
# MarkPricesController
price_f = Float(price, exception: false)
next if price_f.nil? || !price_f.finite? || price_f <= 0 || price_f > 1e15
```
Same shape for `funding_rate` (finite, `abs <= 0.05` is a sane per-settlement bound — Binance caps around 0.75%/8h by formula), and require `funding_time` to parse via `Time.zone.parse` or reject the request with 422 rather than casting to `nil`. Pair with a regression spec: `post :create, params: { prices: { "BTCUSDT" => "garbage" } }` → no `LiquidationJob` enqueued, original price retained.

### M4. Position accounting has a lost-update race, and the uniqueness index that's supposed to back it does not fire for EQUITY/CRYPTO contracts

**Evidence.** `PositionManager.apply!` (`app/services/exchange/position_manager.rb:36-37`) does `find_by(contract_scope) || PaperPosition.new(...)` with **no row lock** on the normal fill path, then computes `new_qty = current_qty + fill_qty` and saves (lines 43-48). Two concurrent submissions for the same contract (parallel agent calls, or an order racing a liquidation close) both read the same `current_qty` and the second write silently drops the first fill — e.g. two 0.1 BTC buys from flat yield one 0.1 BTC position instead of 0.2, while two trades and two ledger entries exist. The safety net you'd expect — `index_paper_positions_uniqueness` on `(account_id, symbol, instrument_type, option_type, strike_price, expiry_date)` (`db/schema.rb:162`) — is defeated by SQL NULL semantics for exactly the instrument types that trade most here: `CRYPTO_PERPETUAL` and `EQUITY` rows have `option_type/strike_price/expiry_date = NULL`, and **Postgres treats NULLs as distinct in unique indexes**, so concurrent `new` records both insert successfully → two position rows for the same contract, and every later `find_by` picks one arbitrarily. The comment block at `position_manager.rb:4-19` documents the contract identity design beautifully — the DB constraint just doesn't enforce it for NULL-nullable dimensions. Note the reduce-only path *does* lock (`paper_exchange.rb:237`, `scope.lock`), which shows the fix pattern is already in-house.

**Fix (two parts, both small):**
1. Lock the row (or the gap) inside the fill transaction:
```ruby
position = ::PaperExchange::PaperPosition.lock.where(contract_scope).first
position ||= ::PaperExchange::PaperPosition.new(contract_scope.merge(side: fill_side, quantity: 0, avg_price: 0))
```
`SELECT ... FOR UPDATE` on a missing row doesn't block a concurrent insert of the same key, so also rescue `ActiveRecord::RecordNotUnique` around `save!` and retry once (the same dance `submit_order` already does for `client_order_id` at `paper_exchange.rb:79-84`).
2. Make the index NULL-safe with an expression index (new migration):
```ruby
add_index :paper_exchange_positions,
  %w[account_id symbol instrument_type],
  unique: true,
  name: "index_paper_positions_contract_strict",
  where: "option_type IS NULL AND strike_price IS NULL AND expiry_date IS NULL"
# keep the existing composite index for options contracts (all columns non-NULL)
```
Or normalize the three nullable columns to sentinel non-NULL values. Then add a concurrency regression spec (two threads submitting the same contract, join, assert one row and summed quantity) — the `ruby-concurrency` skill's ownership model is exactly what's missing here.

### M5. The risk gate fails open, and its rejection events are rolled back by the very transaction that rejects the order

**Evidence.** Two independent defects in `app/services/risk/risk_manager.rb`:
1. **Fail-open:** `rescue => ex` (line 19) returns `[]`. Back in `paper_exchange.rb:113-116`, `_passed, rejected = result` destructures `[]` → `rejected` is `nil` → `Array(nil).any? { … }` is false → **no raise → the order proceeds with zero risk checks**. If any validator so much as raises (a `NoMethodError` in a new validator, a transient DB hiccup in `PositionLimitValidator`'s count), the gate silently evaporates. A risk system's failure mode must be closed.
2. **Vanishing evidence:** on a legitimate rejection, `events.each { RiskEvent.create! … }` (line 15) runs *inside* `PaperOrder.transaction` (opened at `paper_exchange.rb:91`), and the subsequent `raise "Risk check failed"` (line 115) rolls the whole transaction back — **the `*_REJECTED` `RiskEvent` rows are never persisted**. `GET /api/risk_events` can therefore only ever show `POSITION_LIQUIDATED`, `LIQUIDATION_FAILED`, and `RISK_EVALUATION_ERROR` rows; the entire rejection history the endpoint exists for is unwritten. No spec catches this because `risk_manager_spec.rb` only tests the all-validators-mocked-pass case, and transactional fixtures would mask it anyway.

**Fix.**
1. Fail closed: in the `rescue`, log loudly and either re-raise (order rejects with a 500-ish "risk evaluation failed") or return a synthetic `[:RISK_EVALUATION_ERROR_REJECTED]`-style rejection event — either is defensible; "silently pass" is not.
2. Move rejection-event persistence out of the doomed transaction. Cleanest: have `RiskManager.evaluate` only *decide*, and let `submit_order`'s existing `rescue => e` path (line 178-180, which already runs post-rollback when it calls `order.rejected!`) also persist the `RiskEvent` rows. Alternative: wrap event creation in a separate connection/transaction — but the rescue-path approach requires no new machinery.
3. Add specs: a validator raising → order must NOT fill; a rejected order → `RiskEvent` rows exist after the request (run with `use_transactional_fixtures` still on — the rescue path writes after rollback, so the assertion is meaningful).

### M6. `LiquidationJob` reports `POSITION_LIQUIDATED` even when the close order never filled — and the position is simultaneously de-armed from monitoring

**Evidence.** `app/jobs/liquidation_job.rb:20-52`: `submit_order` returns the order whatever its status. If matching fails (e.g. no price in `MarkPriceStore` because the app restarted between the push and the job run, or the book raises — `matching_engine.rb:23-26` rescues *any* error, marks the order rejected, and returns `[:rejected, msg]`), `fill_qty` is nil, the fill block is skipped, and the job still falls through to `RiskEvent.create! … "POSITION_LIQUIDATED"` (line 40-52) with `close_order_id` pointing at a *rejected* order. Meanwhile `LiquidationEngine.check_symbol!` (`liquidation_engine.rb:41`) already removed the position from its in-memory cache when it enqueued the job — and nothing re-adds it (the cache is only rebuilt on the next mark-price push for that symbol *or* on boot). Net effect: an underwater, still-open position that (a) the risk log says was liquidated and (b) nobody is watching until the next push happens to rebuild the cache.

**Fix.** After `submit_order`, assert the outcome before declaring victory:
```ruby
return unless order.status == "filled"   # or check position.reload.quantity.zero?
```
On non-filled: emit `LIQUIDATION_FAILED` with the order's `rejection_reason`, and call `Risk::LiquidationEngine.refresh_cache!` (cheap, already exists) so the position is re-armed for the next push; let the job raise or retry per your retry policy so Solid Queue's retry becomes the re-drive. Add a regression spec that clears `MarkPriceStore` before `perform_later … perform_enqueued_jobs` and asserts a `LIQUIDATION_FAILED` (not `POSITION_LIQUIDATED`) event and a still-armed cache.

### M7. `GET /api/positions/:id` always returns 404

**Evidence.** `app/controllers/api/positions_controller.rb:10`: `positions.find { |p| p[:id] == params[:id] }`. `PositionProjection` returns `id: pos.id` — an `Integer` — while `params[:id]` is a `String`. `1 == "1"` is false in Ruby, so the block never matches and every request 404s (after loading and projecting the account's entire position list, incidentally). The endpoint has no spec coverage — `positions_controller_spec.rb` only exercises `#index` — which is how a total break ships silently.

**Fix.** `positions.find { |p| p[:id].to_s == params[:id] }` (or query the model directly: `PaperPosition.find_by(id: params[:id], account_id: @account_id)` then project the single row — one query instead of a full projection scan). Add the `#show` spec with both a valid and a foreign-account id (the latter asserting 404, per the security-skill's no-existence-oracle guidance).

---

## SHOULD FIX

### S1. Order state transitions are unguarded — you can cancel a filled order and overwrite its status

`paper_order.rb:75-83` `cancel!` happily transitions from any status; `PaperExchange#cancel_order` (`paper_exchange.rb:183-187`) doesn't check either. Cancelling an already-filled order rewrites `status: :filled → :cancelled` (the margin-release no-ops thanks to the `locked_margin.zero?` guard at `paper_exchange.rb:253`, so no money is lost — but the order history now lies, and any downstream logic keying on status misbehaves). Same for `expired!`/`open!`. **Fix:** guard the transitions with the enum's built-in mechanism — `update!(status: :cancelled, …)` inside `cancel!` becomes `paper_order.rb` `def cancel!; transaction do update!(status: :cancelled, cancelled_at: Time.current) end; end` with a precondition `raise StateError unless pending? || open?` (Rails enums support `cancel!` guards via `enum :status, … ` plus explicit checks, or use AASM-style `from:` if you want the machinery). Also make `cancel_order`/`expire_order` load with `.lock` like `set_order` already does in the controller.

### S2. `expire_order` is broken (no `expired_at` column) and nothing ever expires unfilled orders — their margin stays locked forever

`paper_exchange.rb:189-193` calls `order.expired!`, which does `update!(… expired_at: Time.current)` (`paper_order.rb:116-122`) — but `db/schema.rb` has **no `expired_at` column** on `paper_exchange_orders`, so this raises `ActiveRecord::UnknownAttributeError`. Grep confirms `expire_order` has zero callers, so it's latent. The live consequence: bounded/stop orders that aren't marketable return `[:unfilled, nil]` (`matching_engine.rb:42-44`), the order stays `open`, and the margin locked at `paper_exchange.rb:104-110` is released only by an explicit agent `DELETE /api/orders/:id`. An agent that forgets (or crashes) leaves funds locked indefinitely. **Fix:** add the `expired_at` column (one migration), then either wire a periodic expiry sweep into `config/recurring.yml` (Solid Queue recurring is already configured there for cleanup) — e.g. expire `open` orders older than `N` minutes with `locked_margin > 0` — or document loudly in the README that open-order margin is agent-managed and cancellation is the only release path. The sweep is the safer default.

### S3. `MarginValidator` and the actual lock disagree for unleveraged instruments

`margin_validator.rb` computes required margin as `notional * ratio` (10–20% for EQUITY/F&O, lines 21-26) and its comment claims "check #2 rejects before any state mutation". But the actual lock in `paper_exchange.rb:102-110` is `order.required_margin(reference_price)` = `notional / leverage` — with the default `leverage = 1` for EQUITY/F&O, that's **100% of notional**, not 10–20%. Result: an equity order at 50% of balance passes the validator and then dies at `MarginLedger.lock_margin!` with `InsufficientMarginError` (a 402 instead of the intended pre-mutation 422), and the documented "ratio-based equity margin model" comment doesn't match the code. **Fix:** make them agree — either (a) lock `notional * ratio` for non-crypto instruments and release on fill (matching the comment), or (b) change the validator to check full notional for unleveraged instruments (matching the code) and fix the comment. (b) is the smaller diff and the more honest gate.

### S4. `Ledger.compute_realized_pnl` has a bare `rescue` that silently reports zero PnL — and it gets cached into the account row

`ledger/ledger.rb:75-77`: `rescue; 0.0`. Any failure while summing the ledger (DB blip, type cast) silently produces `0.0`, which `refresh_cached_equity!` (line 41-51) then **persists** into `account.realized_pnl` / `current_equity` via `update_columns` — a corrupted snapshot with no log line. This is exactly the "narrowest recoverable exception at the appropriate boundary" anti-pattern the best-practices skill calls out. **Fix:** delete the rescue (let the caller's transaction fail loudly), or at minimum `rescue => e; Rails.logger.error(...); raise` — never return a fabricated number from a financial computation.

### S5. Selling at a price where charges exceed proceeds makes the whole order fail validation

`ledger/ledger.rb:6`: for a sell, `credit = price * qty - total_charges`. For a cheap option (sell 1 lot at ₹0.05 with ₹20 brokerage floor + STT), credit goes negative, `LedgerEntry`'s `credit >= 0` validation rejects it, `record_trade` raises, and the entire order transaction rolls back — the trader sees an opaque 500/422 for a legitimate trade. **Fix:** net it properly: `credit = [proceeds - charges, 0].max` plus `debit = [charges - proceeds, 0].max`, or record gross credit and put charges in `debit` on the same entry (double-entry style, which the payload already half-implies).

### S6. `MarginEngine.sync_position!` has the same read-modify-write race as M4, and can double-lock margin

`margin_engine.rb:24-32`: `delta = required - position.initial_margin` is computed from an unlocked read; two concurrent fills on the same contract both compute their delta from the same baseline and both call `lock_margin!` — the account's `locked_margin` ends up over-locked by one delta, and the trailing `update_columns(initial_margin: …)` (line 40) is last-writer-wins. Once M4's row lock is in place inside `PositionManager.apply!` and `sync_position!` is called on the *same locked instance* (it is — `paper_exchange.rb:147` passes the position returned by `apply!`), this race largely evaporates; make sure the lock is taken before the `delta` read, not after. Worth one concurrency spec to pin it.

### S7. Roughly a third of `app/services` is unreachable from the runtime — spec-only scaffolding presented as features

Caller tracing (grep across `app/`, `config/`, `db/`, no matches outside their own files and specs): `MarketData::TickProcessor`, `MarketData::CandleBuilder`, `MarketData::GreeksService`, `MarketData::OptionChainService`, `Strategy::StrategyEngine`, `Strategy::IndicatorEngine`, `Strategy::MarketStructureEngine`, `Strategy::OptionSelector`, `Risk::VixGate` (superseded by `VixGateValidator`), `PaperExchange#market_event` (referenced only by an error *message* at `order_book.rb:53`), `PaperExchange#expire_order` (S2), and `BinanceUsdmFuturesCatalog.fetch_instruments` (nothing in app/config/db calls it). The README markets "Strategy layer" and the unified event model as key features. Per the best-practices dead-code discipline (verify callers → remove or wire) and the test-engineering boundary-selection guidance (specs that test code with no production caller test an aspiration, not a contract): **fix** by either wiring the intended paths (e.g. `market_event` → `POST /api/market_events` so the order book accumulates real depth per process) or moving these to a clearly-labeled `app/services/roadmap/` (or a feature-flagged module) and trimming the README's feature table to reality. Also remove the unused `sidekiq` gem from the Gemfile — the configured adapter is Solid Queue everywhere (`production.rb:47`, Rails 8.1 default), so Sidekiq is pure supply-chain surface and boot cost.

### S8. `set_account` (including the test-scaffolding hack) is copy-pasted, and `AccountsController` inherits from the wrong base

`api/base_controller.rb:3-18` and `api/accounts_controller.rb:83-91` duplicate the identical header-resolution + `test-api-key-123` remap logic, and `AccountsController < ApplicationController` while every other API controller inherits `Api::BaseController`. Any future change to account resolution (e.g. the M2 auth fix) must be made twice and will rot. **Fix:** `AccountsController < Api::BaseController`, delete the duplicated method.

### S9. Config/docs drift: the documented drawdown env var does nothing, and defaults disagree

Three concrete instances: (1) `README.md:119` and `.env.example:17` document `PAPER_EXCHANGE_MAX_DRAWDOWN` (default `0.20`), but the code reads `PAPER_EXCHANGE_MAX_DD` with default `0.10` (`max_drawdown_validator.rb:3`) — setting the documented var is a no-op and the effective default is 5× stricter than documented; (2) `Account.set_defaults` (`account.rb`) uses `PAPER_EXCHANGE_MARGIN` default `100000` while `.env.example` and the README smoke-test say `10000`; (3) README says execution_price fills get "a small deterministic slippage model … still applie[d] on top", but `paper_exchange.rb:123` + `fill_engine.rb:11` pass `exact_price` which *bypasses* slippage entirely. **Fix:** rename the env var to the documented name (or vice versa) with a deprecation read of the old one; align the defaults; fix the README sentence. Add a tiny spec asserting the documented env var actually changes validator behavior — that's the regression test for this whole class.

### S10. Zeitwerk is being fought with explicit requires, loader unregistration, and late inflections

`config/initializers/exchange_catalogs_loader.rb` `require`s the two catalog files directly and **unregisters the DhanHQ gem's own Zeitwerk loader**; `config/application.rb` registers `dcx:/usdm:` inflections in `config.after_initialize` — which is *after* the moment autoloading/eager-loading needs them, and is precisely why the explicit requires exist. `binance_usdm_futures_catalog.rb` additionally self-aliases `BinanceUsdmFuturesCatalog = BinanceUSDMFuturesCatalog`. This combination works today but is the canonical anti-pattern the `rails-zeitwerk` skill warns about: double-load hazards on eager load, and inflection rules that don't apply when constants are first looked up. **Fix:** move the inflections into `config/initializers/inflections.rb` (the file already exists for exactly this), delete the explicit requires and the loader-unregister (if DhanHQ's loader genuinely conflicts, prefer `Rails.autoloaders.main.ignore` on the gem's paths), and name the class/file so no alias is needed.

### S11. `POST /api/account/reset` deletes across five tables with no wrapping transaction

`accounts_controller.rb:53-58`: five sequential `delete_all` calls (FK-ordered correctly — nice) but no `Account.transaction` — a crash mid-reset leaves a half-wiped account whose ledger no longer matches its positions. Dev/test-only endpoint, so severity is low, but it's a one-line fix: wrap the deletes + account upsert in a transaction.

### S12. Outbound HTTP has no timeouts

`binance_usdm_futures_catalog.rb:9`: `Faraday.get(url)` with no `timeout/open_timeout` options — a slow Binance response hangs the calling thread up to the default (60s each direction). Currently unreachable from the request path (S7), so fix it when you wire it: `Faraday.new(url:) { |f| f.options.timeout = 5; f.options.open_timeout = 2 }` (the `faraday-retry` gem is already in the Gemfile — use it here too). Same review applies to the DhanHQ/coindcx client configuration when they gain runtime call sites.

### S13. `database.yml`'s `max_connections` is not a thing

`config/database.yml` sets `max_connections` under `default` — Active Record's pool key is `pool`; the comment block even links the pooling guide. The key is silently ignored, and the pool falls back to 5 regardless of `RAILS_MAX_THREADS`. With `threads_count = 3` you're fine today, but the setting implies a guarantee it doesn't provide. **Fix:** rename to `pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>`.

### S14. `PerformanceMetrics` recomputes the whole portfolio three times per request, and can emit `Infinity` into JSON

`performance_metrics.rb` calls `PortfolioProjection.summary(account_id)` three separate times (lines 12, 19, 26) — each call re-projects every position, hits `MarkPriceStore` per symbol, and re-sums the ledger twice (`compute_realized_pnl`). Memoize it once (`summary = PortfolioProjection.summary(account_id)`). Separately, `profit_factor` can be `Float::INFINITY`, which with Oj in the stack becomes invalid JSON or `null` depending on mode — serialize it as a string or cap it. Both are five-minute fixes.

### S15. Per-request `PaperExchange` instances make the in-memory order book and mutex request-scoped theater

`orders_controller.rb:27` and `liquidation_job.rb:17` each build a fresh `Exchange::PaperExchange`, whose `@books = {}` + `Mutex` (`paper_exchange.rb:24-26`) therefore live for one request/job — the mutex guards nothing cross-request, and any book accumulated via `apply_snapshot` evaporates. Cross-request pricing actually works only because `MarkPriceStore` (Redis) is the real store and `OrderBook#default_book` falls back to it (`order_book.rb:50-61`). This is functional but misleading: the code *looks* like it maintains a durable book. **Fix:** either extract the truly stateless pieces (slippage/latency/matching are stateless anyway) and drop the per-instance book/mutex, or make the order book a process-level singleton fed by a real endpoint (which `market_event` at S7 hints at). Either way, update the class comment to state the actual lifetime.

---

## NICE TO HAVE

- **N1. Guard enum transitions declaratively.** Beyond the S1 fix, consider expressing legal transitions once (`pending → open → {filled, partially_filled, cancelled, expired, rejected}`) and asserting them in a model spec — cheap insurance against future foot-guns.
- **N2. `LedgerEntry.event_type` casing is inconsistent.** `"trade"` (lowercase, `ledger.rb:10`) vs `"MARGIN_LOCKED"`, `"FUNDING_FEE"`, `"REALIZED_PNL"` (uppercase). Pick one convention (uppercase reads as event-sourced) and add a model format validation so drift can't return.
- **N3. Ledger immutability is convention, not enforcement.** The README and comments say "append-only", but nothing stops an `update`/`delete` (and `AccountsController#reset` deletes them wholesale). Minimum: `def readonly?; persisted? ? super : false; end`-style guard on the model plus a note; belt-and-braces: a Postgres rule/trigger blocking UPDATE/DELETE outside maintenance. The Reconciler's whole design assumes immutability — worth protecting.
- **N4. `MarkPriceStore`'s process-local cache never expires.** `local_cache[key]` (`mark_price_store.rb:29`) is only cleared by `clear` — a web process that once wrote a symbol serves its own last value forever even if Redis has fresher data from another process. A short TTL (or read-through refresh when the local value is older than N seconds) closes the window; low priority because pushes are frequent.
- **N5. CORS `origins "*"`** (`cors.rb:10`) — with M2's auth in place, scope it to the agent's actual origin or drop rack-cors (non-browser clients don't need it).
- **N6. List endpoints have a hard cap but no pagination.** Orders: 200, ledger: 500, risk events: 200 — silently truncated for active accounts. Cursor pagination on `(occurred_at, id)` is the honest version; at minimum document the cap.
- **N7. Dead variable in `AccountsController#show`.** `locked_total` (`accounts_controller.rb:26`) is computed and never rendered — either expose it (it's arguably the most useful "locked" number, since it includes position margin) or delete it.
- **N8. Test-suite gates.** SimpleCov is configured but has no coverage threshold (`spec/support/simplecov.rb`); consider `SimpleCov.minimum_coverage` per group once the M5/M7 specs land, and add an eager-load check to CI (`Rails.application.eager_load!` smoke test) — it would have caught the S10 Zeitwerk fragility class.
- **N9. Document the liquidation-cache blind window.** `LiquidationEngine`'s cache only rebuilds on mark-price pushes (and boot) — a leveraged position opened *after* the last push for its symbol is unmonitored until the next push. By design and bounded by the agent's push cadence, but one sentence in the README's market-data section would prevent a future "why didn't it liquidate" mystery.
- **N10. Verify brokerage rates against the current FY schedule.** `brokerage_calculator.rb` hardcodes STT/GST/SEBI/stamp constants (e.g. equity delivery STT at 0.025% buy-side); rates have changed repeatedly in recent budgets. Env-tunable already — just re-baseline the numbers and cite the schedule in a comment.

---

## What's done well (keep doing this)

The tone of this review is necessarily defect-heavy, so the strengths deserve equal billing — several of these are patterns many production Rails apps don't have:

1. **Idempotent order submission is textbook.** `client_order_id` with a pre-check *plus* a unique-index rescue-and-replay (`paper_exchange.rb:50-54, 79-84`) is exactly the right two-layer TOCTOU-safe design.
2. **`MarginLedger` is real wallet engineering.** Every movement under `Account.lock` (`SELECT ... FOR UPDATE`), insufficient-balance raise, unlock clamped to the current locked amount (double-unlock-proof, `margin_ledger.rb:52`), and a paired immutable entry per movement. This is the discipline that makes the Reconciler possible.
3. **The Reconciler is a genuinely good event-sourcing safety net** — wallet state derivable purely from the ledger, drift corrected with visible `ADJUSTMENT` entries, boot-time re-arm of the liquidation cache (`reconciler.rb`), and correctly skipped in test env.
4. **`FundingJob` idempotency** via the `(paper_position_id, funding_time)` unique index with partial-index dedup — right tool, right place.
5. **`LiquidationJob` re-checks against the DB, not the stale cache that enqueued it**, and the `internal: true` flag solving the B3 self-deadlock (force-close needing margin from an underwater account) shows real iteration on hard problems. The B1-B6/H1/B3/B4 comment trail reads like engineering history worth keeping.
6. **The reduce-only two-phase clamp** (ad advisory pre-check, then authoritative re-read under row lock before fill, `paper_exchange.rb:219-232`) is a sophisticated race-aware design.
7. **Schema quality**: `decimal(36,18)` everywhere money lives, sensible composite indexes, FKs on trades/funding, partial unique index for funding dedup.
8. **CI toolchain** (brakeman, bundler-audit, rubocop-omakase, postgres service for tests) and the **TypeScript smoke-test invariants table** — the latter is a rare and excellent idea (executable documentation of the accounting contract).

---

## Testing assessment

**Shape:** 53 spec files, ~213 examples; strong unit coverage of the engine math (matching/slippage/margin/liquidation calculators all have dedicated specs), 3 integration specs, FactoryBot factories, VCR/WebMock wired. Reasonable foundation with specific gaps:

- **`risk_manager_spec.rb` tests almost nothing**: all four validators are mocked to pass and only "events is nil" is asserted. No rejection path, no error path, no RiskEvent persistence assertion — which is precisely why M5 (both halves) is invisible. Rewrite without mocks: a real account + a signal that trips one real validator.
- **`GET /api/positions/:id` is untested** (M7) — the classic "the endpoint that never worked" pattern.
- **Integration depth is thin for the claims**: `trading_lifecycle_spec.rb` has 2 examples, `paper_lifecycle_spec.rb` 4. The heavy lifting for lifecycle verification lives in the TS smoke suite, which is great — but it runs against Docker and isn't in CI; the RSpec integration specs should cover at least: multi-fill weighted average, reduce-then-reverse (side flip), and the ledger cash invariant from the smoke-test table (they're cheap to write and pin the core contract).
- **Boundary selection** (per the test-engineering skill): controller specs use `get :index` controller-style tests; for HTTP contracts, request specs (`get "/api/orders", headers: …`) would exercise routing + headers + serialization — the actual contract the agent consumes. Worth migrating opportunistically.
- **No concurrency specs anywhere** despite the domain being full of them (M4, S6). A couple of thread-based specs (or Minitest-style parallel assertions) on `PositionManager.apply!` and `MarginLedger` would pin the money-critical invariants.
- **Transactional fixtures + the M5 rollback bug** are a cautionary pair: when a feature's writes are supposed to survive an inner rollback, a transactional-fixture spec can't tell the difference — the M5 regression spec should use `self.use_transactional_tests = false` with explicit cleanup, or assert through a second DB connection.

---

## Evaluation of the `ruby-agent-skills` pack itself

You asked whether the skill pack is correct and where it needs improvement. Short answer: **the content I exercised is technically sound and surprisingly current, the structure is disciplined, and it genuinely improved this review — but it has coverage gaps that this exact audit exposed, and its scale works against its own "pattern restraint" philosophy.**

### Correctness verdict

- **Six skills deep-read** (`agent-workflow`, `rails-best-practices`, `rails-security-engineering`, `rails-test-engineering`, `ruby-concurrency`, `rails-deployment`): **no technical errors found.** Claims are hedged correctly ("signals not laws", "verify in repository context"), Rails guidance is 8.1-current (Local CI via `config/ci.rb`, parallelize semantics, enum syntax, ActiveJob test-adapter behavior), and every `Source foundation` section honestly attributes its origin.
- **Structural integrity checks passed:** all 85 skills in `skill-manifest.yml` exist on disk and vice versa (I diffed them); all eight pattern files referenced by the security skill resolve on disk; the apparent duplicate YAML keys in the manifest turned out to be in different top-level sections (`patterns:` vs `benchmarks:`) — a false alarm, but the fact the pack ships its own verification tests (`skill_pack_verification_system_test.rb`) is why it's clean.

### Where the pack earned its keep in this review

- The **security skill's trust-boundary model** (`asset → actor → boundary → … → sink`) is what surfaced M2/M3 in minutes: "API client → Rails with no authn" and "unvalidated input at the boundary that owns the decision" fall straight out of its procedure.
- The **test-engineering skill's boundary-selection and "assert contracts not implementation"** guidance correctly diagnosed the mocked-thin `risk_manager_spec` and the spec-only scaffolding (S7) as testing-aspiration problems.
- The **best-practices dead-code discipline** ("search callers before removal") and the **concurrency skill's ownership model** gave me the vocabulary for M4/S6.
- The uniform **skill contract** (Purpose / Activate when / Repository inspection / Checklist / Verification / Source foundation) made routing fast and made it obvious which skill owned which finding.

### Where the pack needs improvement (all evidenced by this audit)

1. **No money/numeric-correctness skill — the biggest gap.** This is a trading system; the review's core questions were BigDecimal-vs-Float discipline, `decimal(36,18)` scale choices, `.to_f` in equity computation (`ledger.rb:59`), float rounding of cached PnL, and `Float::INFINITY` escaping to JSON (S14). Grepping the pack, BigDecimal appears only incidentally. A `ruby-numeric-money` skill (Float avoidance for value, precision/scale selection, JSON serialization of non-finite numbers, rounding policy at persistence boundaries) would have direct, citable guidance for exactly this repo class.
2. **No Rails enum state-machine guidance.** The unguarded `cancel!`-on-filled class (S1/N1) isn't covered anywhere — grep for enum guidance returns only unrelated `Enumerable` hits. One focused skill (or a section in `rails-activerecord`): legal-transition tables, guard patterns, and testing transitions.
3. **No ledger/double-entry/reconciliation pattern** despite 391 pattern files. `idempotent-request` and `distributed-lock` exist, but append-only ledger design, wallet movement under row locks, drift reconciliation, and event-sourced balance rebuild — the *heart* of this codebase — have no pack coverage. The pack found the bugs here anyway via generic skills, but domain patterns would have made the review faster and the findings more prescriptive.
4. **The pack is change-oriented; audits are improvised.** AGENTS.md's workflow (discover → … → implement → test → review) presumes you're *changing* code. Reviewing a whole foreign repo required synthesizing a methodology from the review-dimensions list plus individual skill checklists. Given that the repo already has `REPOSITORY_COMPLETENESS_AUDIT.md` and a review-history doc, a dedicated `rails-repo-audit` skill (scope → map boundaries → evidence-gathering order → findings format with severity model) would formalize what this session had to invent.
5. **352 Rails patterns defeats selection without the routing harness.** The pack's own routing-campaign machinery (Ollama models, evidence archives) is impressively engineered but unusable for an agent without a local model runtime; the fallback is grepping a 352-file directory. A single index document (pattern name → one-line problem statement → file) or machine-readable tags in pattern frontmatter would give external agents the fast path the manifest gives for skills.
6. **README is a 45KB iteration log.** Iterations 69-79 are documented in detail before any usage guidance; INSTALLATION.md is separate. A new agent (the pack's own target audience!) must wade through changelog-style content to learn the operating sequence that AGENTS.md already states in 12 lines. Suggest: three-paragraph quickstart + link table at the top, iteration log moved to CHANGELOG.md.
7. **Dated source foundation in `rails-best-practices`.** flyerhzm's `rails_best_practices` has been dormant for years. The skill handles this well (explicit "translate to modern Rails" section) but should either refresh the source basis (rubocop-rails covers a large fraction of the same checks) or state the vintage more prominently.
8. **Meta-observation, offered constructively:** the pack's stated philosophy is pattern restraint and "smallest covering skill set", yet the pack itself has grown to 85 skills + 391 patterns + a routing/evidence/benchmark apparatus across 79 iterations. The AGENT_SKILLS_REVIEW.md's own quality outcome ("the goal was not to make every skill longer") applies to the catalog too — consolidation candidates exist (e.g., `rails-activerecord` vs `rails-active-record` vs `rails-associations` naming overlap tripped me twice during routing).

### Bottom line on the pack

For the question "are the skills correct?" — yes, within everything I read and cross-checked. For "do they need improvement?" — not in correctness but in **coverage of domain classes the pack hasn't met yet** (money math, state machines, event-sourced ledgers), **audit-mode support**, and **navigability at its current scale**. Notably, this review itself is a ready-made validation case study: the pack's skills found seven real must-fix defects in a real repo — that's exactly the "evidence, not assumptions" standard the pack preaches, and publishing such case studies would do more for the pack's credibility than another routing iteration.

---

## Suggested fix order

1. **Today:** M1 (rotate key/secrets, purge defaults) — it's a 30-minute chore with permanent downside if skipped.
2. **This week:** M3 + M2 (input validation at the mark-price/funding boundaries; then the smallest auth layer that matches your deployment story).
3. **Next:** M4 + S6 (position row lock + NULL-safe index + retry-once; margin sync on the locked instance) with the concurrency specs — these are the money-integrity races.
4. **Then:** M5 (fail-closed risk gate + events out of the doomed transaction + real specs), M6 (assert filled before POSITION_LIQUIDATED + re-arm cache), M7 (the one-line endpoint fix + spec).
5. **Housekeeping sprint:** S1/S2 (state guards + expiry sweep), S8/S9/S13 (dedupe controller, fix env-var drift, `pool:`), then burn down the S7 dead-code decision (wire or label, and drop sidekiq).
6. **Background:** N-tier items opportunistically, ideally paired with the test-suite migration from controller specs to request specs.
