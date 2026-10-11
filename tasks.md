# Tasks — Development Plan for paper_exchange

> **Primary reader:** AI developer. Last updated: 2026-10-10.
> **Source of truth for the backlog:** the 2026-09-25 full audit (`REVIEW.md`) — 7 MUST (M1–M7), 15 SHOULD (S1–S15), 10 NICE (N1–N10) findings; the 2026-10-10 end-to-end code review (P0/P1/P2); and the 2026-10-10 target architecture (autonomous exchange). This file sequences them into executable tasks.
> **Update protocol:** when you start a task set status `In Progress`; when done set `Done`, check off acceptance criteria, and append any decision/learning to `memory.md`. Add new tasks at the bottom of their phase — never reorder closed items.

**Status:** `TODO` · `In Progress` · `Done` · `Blocked` (state blocker in Notes)
**Priority:** `P0` = security/data-integrity emergency · `P1` = broken contract or race on money path · `P2` = correctness debt · `P3` = hygiene/polish
**Current phase: Autonomous exchange architecture complete (2026-10-10).** All P0/P1/P2 findings from the end-to-end review are fixed. The 3-process topology is wired. Remaining: T4.3/T4.4 housekeeping, T5.3 test gates, and the Phase 6 roadmap items (depth-consuming partial fills, live broker adapters, indicator/candle/greeks wiring).

---

## Phase 0 — Security emergency (do today; ~half a day)

- [x] **T0.1 · P0 · Done — Rotate the leaked master key & purge committed secrets (audit M1)** — merged to main via PRs #30/#33 (purge + CI secret guard, 2026-09-25) and completed 2026-09-26 on branch `feat/audit-clean-v1`: `config/credentials.yml.enc` re-encrypted under a fresh master key with a fresh `secret_key_base` (verified cryptographically — the old key fails GCM auth against the new file). New key delivered to the operator out-of-band, stored only in uncommitted `.env`.
  Evidence: `.env.example:4` shipped a real `RAILS_MASTER_KEY` that **decrypts `config/credentials.yml.enc`** (verified cryptographically); `docker-compose.yml` hardcodes it as the `:-` default; key exists in git history.
  **Accept when:** committed key can no longer decrypt the new credentials file ✓ · `docker compose up` without `.env` fails loudly ✓ · CI guard catches a planted 64-hex string ✓ (verified in PR #30) · `SECRET_KEY_BASE` in `.env.example` is a placeholder ✓.

- [x] **T0.2 · P0 · Done — Validate mark-price & funding inputs at the boundary (audit M3)** — 2026-09-26, `feat/audit-clean-v1`: `Float(x, exception: false)` + `.finite?` + `> 0` + ceiling `1e15` (whole request 422, nothing applied, prior prices retained); funding rate bounded `abs <= 0.05`; unparseable `funding_time` → 422; optional `mark_price` validated like a mark price.
  **Accept when:** regression spec posts `prices: { "BTCUSDT" => "garbage" }` → no `LiquidationJob` enqueued, prior price retained, 422 ✓ · garbage `funding_rate` rejected ✓ · `funding_time: "not-a-time"` rejected with 422 ✓.

## Phase 1 — Broken contracts & trust boundary (this week)

- [x] **T1.1 · P1 · Done — Fix `GET /api/positions/:id` (audit M7)** — merged to main via PRs #30/#33 (2026-09-25): `PositionProjection#for_id(account_id, id)` queries by id AND account (foreign id → plain 404, no existence oracle); controller early-returns 404; 3 request-level specs (valid/unknown/foreign-account).
  **Accept when:** request specs cover valid id (200, projected shape), foreign-account id (404, no existence oracle), unknown id (404) ✓ · endpoint listed as consumable in `design.md` §2 ✓ (⚠ removed 2026-09-26).

- [x] **T1.2 · P1 · Done — Minimal authentication: shared bearer token (audit M2, minimum option)** — 2026-09-26, `feat/audit-clean-v1`: `X-API-Key` must equal `ENV["PAPER_EXCHANGE_API_KEY"]` via `before_action` in `Api::BaseController` (constant-time `secure_compare`), 401 otherwise; production fails boot without the key (`config/initializers/api_authentication.rb`); CORS tightened `origins "*"` → loopback only (N5); X-API-Key removed as an account-id source (B4 scaffolding deleted); README documents the trust model; docker-compose requires the key loudly.
  **Accept when:** unauthenticated request to every route group under `/api` → 401 ✓ (request spec covers all 8 groups) · authenticated flow unchanged ✓ · README documents the trust model ✓ · one request spec per route group ✓.

- [x] **T1.3 · P2 · Done — Controller hygiene prerequisite (audits S8 + S11)** — 2026-09-26, `feat/audit-clean-v1`: `AccountsController < Api::BaseController` (duplicated `set_account`/`render_error` deleted — it also now sits behind the auth layer); reset five-table wipe wrapped in `Account.transaction`; dead `locked_total` variable dropped (N7).
  **Accept when:** zero duplicated account-resolution logic ✓ · reset spec asserts all-or-nothing (simulated mid-wipe failure → nothing deleted) ✓.

## Phase 2 — Money integrity races & risk-gate correctness (next)

- [x] **T2.1 · P1 · Done — Position upsert: row lock + NULL-safe unique index + retry (audit M4)** — 2026-09-26, `feat/audit-clean-v1`: `.lock.where(contract_scope)` inside a savepoint in the fill transaction; partial unique index `index_paper_positions_contract_strict` on `(account_id, symbol, instrument_type) WHERE option_type IS NULL AND strike_price IS NULL AND expiry_date IS NULL` (migration 20260926100000, with pre-dedup of any existing NULL-dimension rows); `rescue ActiveRecord::RecordNotUnique` → retry once (savepoint makes the violation recoverable inside the caller's transaction).
  **Accept when:** concurrency spec (two threads, same contract from flat, join) → exactly one position row, quantity = sum ✓ · duplicate-row attempt raises the unique violation and is handled ✓ (model spec).

- [x] **T2.2 · P1 · Done — Margin sync under the same lock (audit S6)** — 2026-09-26: `PositionManager.apply_locked!` returns the locked, mutated instance; `MarginEngine.sync_position!` documents + receives that contract (delta computed from the in-memory post-fill attributes). Concurrency specs assert one row and summed quantity through the same path.
  **Accept when:** concurrency spec on double-fill same contract → no lost updates, `initial_margin` last-writer-wins eliminated ✓.

- [x] **T2.3 · P1 · Done — Risk gate: fail closed + persist rejection events post-rollback (audit M5)** — 2026-09-26: `rescue` in `risk_manager.rb` returns synthetic `RISK_EVALUATION_ERROR_REJECTED` (never `[]`; logged loudly); `RiskManager.evaluate` decides only; rejection `RiskEvent` rows persisted in `submit_order`'s post-rollback rescue via new `RiskCheckFailedError` carrying the rejection symbols; controller maps it to 422.
  **Accept when:** spec with a raising validator → order NOT filled ✓ · spec with a tripped validator → `*_REJECTED` `RiskEvent` rows exist after the request ✓ (transactional tests kept on — the rescue path writes after rollback) · `risk_manager_spec.rb` rewritten without mocked validators ✓.

- [x] **T2.4 · P1 · Done — Liquidation outcome assertion + cache re-arm (audit M6)** — 2026-09-26: `LiquidationJob` requires `order.status == "filled"` before emitting `POSITION_LIQUIDATED`; on non-filled emits `LIQUIDATION_FAILED` with `rejection_reason`, cancels the orphan open close order, and calls `Risk::LiquidationEngine.refresh_cache!` to re-arm (next push re-drives; deliberately no raise — avoids infinite retry on permanently-rejected closes).
  **Accept when:** spec clears the order book before performing the job → `LIQUIDATION_FAILED` (not `POSITION_LIQUIDATED`), cache still armed, position still open ✓.

## Phase 3 — State machine & config hygiene (housekeeping sprint)

- [x] **T3.1 · P2 · Done — Guarded order-state transitions (audits S1 + N1)** — 2026-09-26: `cancel!`/`open!`/`filled!`/`partially_filled!`/`expired!` assert legal source states and raise `PaperOrder::StateError`; `rejected!` deliberately unguarded (terminal safety net); `cancel_order`/`expire_order` load with `.lock`; `DELETE /api/orders/:id` maps StateError → 409. Model spec asserts the full legal-transition table.
- [x] **T3.2 · P2 · Done — Order expiry actually works (audit S2)** — 2026-09-26: `expired_at` column added (migration 20260926110000); `ExpireOrdersJob` sweeps open orders older than `PAPER_EXCHANGE_ORDER_TTL_MINUTES` (default 60) every 5 minutes via `config/recurring.yml`, releasing locked margin; raced orders skipped via the T3.1 guard. Job specs cover stale/fresh/terminal/raced.
- [x] **T3.3 · P2 · Done — Env-var & docs alignment (audit S9)** — 2026-09-26: `MaxDrawdownValidator` reads documented `PAPER_EXCHANGE_MAX_DRAWDOWN` (default 0.20; old `PAPER_EXCHANGE_MAX_DD` spelling still honored); `Account.set_defaults` margin default aligned 100000 → 10000; README `execution_price` claim fixed (it bypasses slippage). New `max_drawdown_validator_spec` asserts default + boundary behavior.
- [x] **T3.4 · P2 · Done — `database.yml`: `max_connections` → `pool:` (audit S13)** — 2026-09-26.
- [x] **T3.5 · P2 · Done — Margin validator vs actual lock agreement (audit S3)** — 2026-09-26: option (b) — validator checks full notional for unleveraged instruments (matches what submit_order actually locks); ratio table removed; spec: oversized/50%-of-balance equity order → clean 422 pre-mutation (not 402).
- [x] **T3.6 · P2 · Done — No silent zero-PnL (audit S4)** — 2026-09-26: bare `rescue; 0.0` removed from `compute_realized_pnl`; money-path failures raise. Spec asserts the raise propagates.
- [x] **T3.7 · P2 · Done — Net sell proceeds vs charges (audit S5)** — 2026-09-26: `credit = [proceeds - charges, 0].max`, uncovered remainder into `debit`; spec: cheap option sell no longer produces a negative credit.
- [x] **T3.8 · P3 · Done — Faraday timeouts (audit S12)** — 2026-09-26: Binance catalog `open_timeout: 2, timeout: 5` (the only raw-Faraday call site; other catalogs go through dhanhq/coindcx-client gems).
- [x] **T3.9 · P3 · Done — Performance memoization + Infinity guard (audit S14)** — 2026-09-26: one `PortfolioProjection.summary` call per `for` (was 3); `profit_factor` capped at 999.0 — JSON cannot carry Infinity (serialized as null).

## Phase 4 — Scope honesty (decision-heavy; needs operator input)

- [x] **T4.1 · P2 · Done — Unwired services: wire or remove (audit S7)** — decision recorded 2026-09-26 (see `memory.md` decisions log): **keep in place, mark Roadmap in the README feature table**; wire (e.g. `POST /api/market_events`) or remove in a v1.1 sprint. README Status table now lists every unwired module (strategy/*, tick_processor, candle_builder, greeks_service, option_chain_service, market_event, VIX data source) as Roadmap with an explicit no-runtime-callers note.
- [x] **T4.2 · P3 · Done — Remove unused `sidekiq` gem (audit T4.2)** — 2026-09-26: gem removed, lockfile regenerated (pure 8-line prune; `redis-client` correctly retained as a hard dep of `redis` 6.0.0).
- [ ] **T4.3 · P3 · TODO — Zeitwerk normalization (audit S10)** — inflections → `config/initializers/inflections.rb`; delete explicit requires + loader unregister in `exchange_catalogs_loader.rb`; rename catalog class/file to kill the self-alias. Add eager-load smoke check to CI (pairs with T5.3).
- [ ] **T4.4 · P3 · TODO — Order-book lifetime decision (audit S15)** — either extract stateless engines and drop the per-instance `@books`/`Mutex`, or make the book a process-level singleton fed by a real endpoint. Update the class comment either way.
- [x] **T4.1b · P3 · Done — Wire the v1.1 roadmap modules (follow-up to the T4.1 keep-in-place decision)** — 2026-09-26, `feat/phase5-polish-wiring`: `POST/GET /api/market_events` (feed pushes ticks into the capped Redis stream via a rebuilt class-level `TickProcessor`; all-or-nothing validation, loud 503 when the stream is down), `POST/GET /api/market_structure` (engine now DB-backed on the existing `market_structure_snapshots` table — the in-memory hash never survived a request), `POST /api/strategy/signals` (`StrategyEngine#assess` — read-only pre-trade run of the exact submit-order risk gate, decide-only per M5; `Signal` gained `leverage`). Remaining unwired: indicator engine compute, candle builder, greeks/option chain, option selector — still Roadmap rows in the README.

## Phase 5 — Background polish (opportunistic, pair with test migration)

- [x] **T5.1 · P3 · Done — Enforce ledger immutability (N3)** — 2026-09-26: `LedgerEntry#readonly?` raises on update/destroy of persisted rows; a BEFORE UPDATE trigger (migration 20260926120001, DDL shared via `Ledger::Immutability`) blocks even raw-SQL UPDATEs; DELETE stays allowed for the account-reset wipe. `spec/support/ledger_immutability.rb` re-installs the trigger on schema-loaded test DBs (schema.rb cannot express triggers), so CI tests the real enforcement.
- [x] **T5.2 · P3 · Done — Normalize `event_type` casing (N2)** — 2026-09-26: legacy lowercase `"trade"` → `TRADE` (write + read paths + data migration 20260926120000, which runs BEFORE the immutability trigger); model format validation pins SCREAMING_SNAKE_CASE forever.
- [ ] **T5.3 · P3 · TODO — Test gates (N8)** — `SimpleCov.minimum_coverage`; CI eager-load check (`Rails.application.eager_load!` smoke).
- [x] **T5.4 · P3 · Done — Cursor pagination (N6)** — 2026-09-26: `Api::CursorPagination` concern — keyset `(sort_column, id) DESC`, opaque Base64url cursor, `?limit=` clamped 1–500 (default 100), tampered cursor → 400; envelope `{data, next_cursor}` on orders/ledger/risk_events; composite indexes + `placed_at` NOT NULL (migration 20260926130000).
- [ ] **T5.5 · P3 · TODO — Controller specs → request specs** (migration, opportunistic per file touched).
- [ ] **T5.6 · P3 · TODO — Remaining N-tier** — N4 MarkPriceStore TTL · N7 dead `locked_total` var (done 2026-09-26 in T1.3) · N9 README liquidation-cache blind-window note (done 2026-09-26 — one sentence in "Crypto market data ownership") · N10 re-baseline brokerage rates vs current FY schedule.

---

## Done — MVP baseline (feature work complete; see `prd.md` §4)

Orders with two-layer idempotency · margin wallet under row locks · contract-scoped positions · Redis mark prices · two-phase liquidation pipeline · idempotent funding · append-only ledger + boot reconciler · risk validators · read endpoints · Indian F&O charges · Docker/Kamal/CI toolchain · TS smoke invariant suites.

## Blocked / deliberately deferred

- Per-account API keys (needs multi-operator requirement — `prd.md` non-goal).
- WebSocket streaming (non-goal for MVP).
- ~~Wiring `strategy/*`~~ (decided 2026-09-26 → done same day, T4.1b: market events, market structure, strategy signals wired; indicator compute / candle builder / greeks / option chain / option selector remain Roadmap).

## Release checkpoint: "audit-clean v1"

Exit bar (from `prd.md` §7): T0.x–T2.x all Done (M1–M7 closed with regression specs) ✓ · Phase 3 ≥ 80% ✓ (9/9) · T4.1 decision recorded ✓ · CI includes secret scanning ✓.
**Status: MET on branch `feat/audit-clean-v1` (2026-09-26). Tag `v1.0.0-audit-clean` after it merges to main.**

---

## Phase 6 — End-to-end review + autonomous exchange architecture (2026-10-10)

### Phase 6a — Financial invariants (P0/P1 from the end-to-end review)

- [x] **T6.1 · P0 · Done — Non-crypto wallet/equity accounting model (P0-1)** — `MarginEngine.sync_position!` now locks full notional for leverage-1 positions; `record_trade` posts realized PnL + fees via MarginLedger; `compute_equity` drops `trade_cash_pnl`. The 80% phantom drawdown eliminated. Spec: `equity_accounting_spec.rb`.
- [x] **T6.2 · P0 · Done — Funding settlement atomicity (P0-2)** — `FundingJob` wraps payment + ledger in one transaction; `leverage > 1` filter replaced with `instrument_type = CRYPTO_PERPETUAL`. Spec: `funding_atomicity_spec.rb`.
- [x] **T6.3 · P1 · Done — Max-drawdown from equity high-water mark (P1-1)** — New `max_equity_achieved` column; `MaxDrawdownValidator` uses live equity + persisted HWM. Spec: `drawdown_from_peak_spec.rb`.
- [x] **T6.4 · P1 · Done — Notional-value limit bypass (P1-2)** — One `reference_price` feeds both the risk gate and the margin lock. Spec: `cancel_and_notional_spec.rb`.
- [x] **T6.5 · P1 · Done — NSE FY2026-27 STT schedule (P1-3)** — Options sell 0.15%, futures sell 0.05% (was 0.05% / 0.01%). Env-overridable. Spec: `cancel_and_notional_spec.rb`.
- [x] **T6.6 · P1 · Done — Performance metrics from REALIZED_PNL stream (P1-4)** — `closed_trades_with_pnl` reads from ledger stream grouped by `trade_id`; Sharpe uses `sqrt(252)`. Spec: `performance_metrics_spec.rb` updated.
- [x] **T6.7 · P1 · Done — Cancellation atomicity (P1-5)** — Lock + state + margin release in one transaction; DELETE returns committed state. Spec: `cancel_and_notional_spec.rb`.

### Phase 6b — Trading behavior & data consistency (P1/P2)

- [x] **T6.8 · P1 · Done — Currency consistency gate (P1-6)** — New `Risk::CurrencyValidator` rejects cross-currency orders. Spec: `currency_validator_spec.rb`.
- [x] **T6.9 · P2 · Done — Limit order price improvement (P2-1)** — Bounded orders fill at best available book price clamped to limit. Stop-loss documented as stop-market.
- [x] **T6.10 · P2 · Done — Wallet.locked includes position margin (P2-2)** — `wallet.locked = order_locked + position_locked`.
- [x] **T6.11 · P2 · Done — MarkPriceStore TTL (P2-3)** — Local cache has 2s TTL, re-fetches from Redis.

### Phase 6c — Autonomous exchange architecture (target architecture)

- [x] **T6.12 · Done — SDK dependency alignment** — Gemfile pins `coindcx-client ~> 1.0` (was 0.1.0) and adds `binance-client ~> 0.1`.
- [x] **T6.13 · Done — Provider adapter framework** — `MarketData::Providers::Base` + `BinanceUsdm` + `CoindcxFutures`. Uniform contract: `fetch_instruments`, `fetch_snapshot`, `connect`, `health`, `disconnect`.
- [x] **T6.14 · Done — Venue-aware QuoteStore** — `MarketData::QuoteStore` holds bid/ask/mark/funding per (venue, instrument). `stale?` check for rejecting old quotes.
- [x] **T6.15 · Done — Venue column on orders and positions** — Migration `20261010140000`. BTCUSDT on Binance is distinct from BTCUSDT on CoinDCX.
- [x] **T6.16 · Done — PositionProtection model + migration** — Durable SL/TP/trailing_stop/OCO policies. `breached?`, `update_water_mark!`, `trigger!`, OCO sibling cancellation. Spec: `position_protection_spec.rb`.
- [x] **T6.17 · Done — MatchingWorker** — Event-driven matching: consumes Redis tick stream, fills open orders at live book price. `PaperExchange#match_and_fill`. `MatchingWorkerJob` scheduled every 2s. Spec: `matching_worker_spec.rb`.
- [x] **T6.18 · Done — ProtectionMonitorJob** — Scans active protections every 3s, triggers force-close on breach. Spec: `protection_monitor_job_spec.rb`.
- [x] **T6.19 · Done — OptionExpiryJob** — Daily cash settlement for expiring options (15:30).
- [x] **T6.20 · Done — Exchange status endpoint** — `GET /api/exchange/status`: provider connectivity, quote freshness, matching worker liveness.
- [x] **T6.21 · Done — Position protections API** — `POST/GET/DELETE /api/positions/:id/protections`.
- [x] **T6.22 · Done — ConnectionSupervisor** — Long-lived market-data process skeleton. `bin/market_data` entrypoint.
- [x] **T6.23 · Done — 3-process docker-compose topology** — `web` + `jobs` + `market_data` (behind `--profile market_data`).
- [x] **T6.24 · Done — Recurring job schedule** — `config/recurring.yml`: MatchingWorker (2s), ProtectionMonitor (3s), OptionExpiry (daily), ExpireOrders (5m).
- [x] **T6.25 · Done — Docs updated** — README, architecture.md, design.md, memory.md all reflect the autonomous exchange model.

### Phase 6d — Production hardening (from the prior hardening pass)

- [x] **T6.26 · Done — Global JSON error envelope** — `rescue_from StandardError/RecordNotFound/ParameterMissing` in `Api::BaseController`.
- [x] **T6.27 · Done — Boot Reconciler fatal in production** — Re-raises instead of swallowing.
- [x] **T6.28 · Done — Redis re-enabled in CI** — `.github/workflows/ci.yml` uncomments Redis service.
- [x] **T6.29 · Done — Non-root production container** — Dockerfile `USER 1001:1001`.
- [x] **T6.30 · Done — SSL + DNS-rebinding defaults** — `force_ssl` + `config.hosts` in production.rb.
- [x] **T6.31 · Done — Deep health check** — `GET /health` probes Postgres + Redis + Solid Queue.
- [x] **T6.32 · Done — Foreign keys from money tables to accounts** — Migration `20261010120000`.
- [x] **T6.33 · Done — Funding idempotency regression spec** — `funding_atomicity_spec.rb`.
- [x] **T6.34 · Done — VixGateValidator spec** — `vix_gate_validator_spec.rb`.
- [x] **T6.35 · Done — .env.example expanded** — All ~20 env vars documented.

### Phase 6e — Remaining (roadmap)

- [ ] **T6.36 · TODO — Depth-consuming partial fills** — The matching engine fills the entire remaining quantity without consuming recorded order-book depth. Implement depth consumption for execution-quality analysis.
- [ ] **T6.37 · TODO — Rate limiting (rack-attack)** — Add `rack-attack` to Gemfile; throttle `/api/*` by IP+key; lockbox `POST /api/account/reset` to 5/min/IP. Needs `bundle install` to update lockfile.
- [ ] **T6.38 · TODO — Prometheus metrics** — Add `prometheus_exporter`; expose `/metrics` with counters for order submit/fail, liquidation enqueue/failed, Redis outage count, reconcile drift, queue depth.
- [ ] **T6.39 · TODO — Structured (JSON) logging** — Add `lograge` + `lograge_json` for one-line-per-request machine-parseable logs.
- [ ] **T6.40 · TODO — Audit trail with request.uuid** — Stamp `request.uuid` into `RiskEvent.details` and `LedgerEntry.payload` for forensic correlation.
- [ ] **T6.41 · TODO — Zeitwerk normalization (S10)** — Move inflections to `config/initializers/inflections.rb`; delete loader unregister + self-alias.
- [ ] **T6.42 · TODO — Order-book lifetime (S15)** — Extract stateless engines from `PaperExchange` or make the book a process-level singleton.
- [ ] **T6.43 · TODO — SimpleCov threshold (N8)** — `SimpleCov.minimum_coverage`; CI eager-load check.
- [ ] **T6.44 · TODO — Indicator/candle/greeks wiring** — `IndicatorEngine` compute, `CandleBuilder`, `GreeksService`, `OptionChainService`, `OptionSelector` exist but have no runtime callers.
- [ ] **T6.45 · TODO — Live broker adapters (order routing)** — Currently paper-only; the provider adapters consume public market data only.
