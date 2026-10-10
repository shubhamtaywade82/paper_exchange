# Production-Readiness Review — `paper_exchange`

**Branch:** `prod-ready/hardening` (2026-10-10)
**Scope:** Review the repo against production-readiness criteria and apply
surgical hardening. A prior `REVIEW.md` audit (7 MUST / 15 SHOULD / 10 NICE
findings) was already executed — all 7 MUST issues are confirmed FIXED in the
current tree. This pass closes the remaining operational, security, and
data-integrity gaps that the prior audit did not enumerate, and documents the
larger refactors that require a Ruby runtime to verify (none was available in
the review environment).

> **Verification caveat:** no Ruby runtime was available, so the test suite
> was not executed. Every change below is surgical and designed to be
> spec-safe by construction (additive methods, env-gated behavior, new
> migration + matching `schema.rb` bump, new unauthenticated route). Run
> `bundle exec rspec` after merging to confirm.

---

## 1. Starting point: the prior audit is closed

The existing `REVIEW.md` found seven ship-blocking issues. All are fixed:

| Prior finding | Status | Evidence |
|---------------|--------|----------|
| M1 committed master key | FIXED | `.env.example` placeholders, `docker-compose.yml` `:?` loud-fail, CI hex-secret guard |
| M2 unauthenticated API | FIXED | `Api::BaseController#authenticate_api_key!` constant-time compare + boot guard |
| M3 garbage mark/funding price → mass liquidation | FIXED | `mark_prices_controller.rb` + `funding_events_controller.rb` boundary validation |
| M4 position upsert race | FIXED | `PositionManager#apply_locked!` savepoint + retry, partial unique index |
| M5 risk gate fail-open + rolled-back rejections | FIXED | `RiskManager` fail-closed rescue + post-rollback `RiskEvent` persistence |
| M6 liquidation reports success on unfilled close | FIXED | `LiquidationJob` asserts `filled` + `LIQUIDATION_FAILED` on miss |
| M7 `GET /api/positions/:id` always 404 | FIXED | `PositionProjection#for_id` |

13/15 SHOULD and 7/10 NICE are also fixed. The open SHOULD items (S10 Zeitwerk
normalization, S15 per-request order book lifetime) and open NICE items (N4
MarkPriceStore cache TTL, N8 SimpleCov threshold, N10 brokerage re-baseline)
are carried forward in §3 below.

---

## 2. Hardening applied in this pass

Each item is a concrete file change on this branch. "Risk" reflects the
likelihood of disturbing the existing 300+ spec examples.

### 2.1 API contract & error handling

**[NEW-6] Global JSON error envelope.** `app/controllers/api/base_controller.rb`
adds `rescue_from StandardError → 500`, `rescue_from ActiveRecord::RecordNotFound
→ 404`, and `rescue_from ActionController::ParameterMissing → 400`. Previously
any unhandled exception in `PerformanceController`, `LedgerController`,
`RiskEventsController`, `PositionsController`, `MarkPricesController` bubbled to
Rails' default `ActionController::API` 500 handler, which in production renders
HTML — not the documented `{"error":"..."}` JSON shape. The general
`StandardError` handler is registered **first** (Rails checks handlers
most-recently-registered first) so it acts as a fallback and does not shadow the
specific 400/404 handlers. Local `rescue` clauses (e.g. `OrdersController#create`)
still take precedence. **Risk: low** — only affects previously-unhandled paths.

### 2.2 Reliability

**[NEW-8] Boot Reconciler is fatal in production.** `config/initializers/reconciler.rb`
now re-raises in `Rails.env.production?` instead of logging-and-continuing. The
core trust invariant is "wallet == Σ ledger entries" (`prd §6.1`); booting with
an unreconciled wallet lets orders through that should not pass. Dev/test keeps
the swallow so `db:create` / first-boot flows still work. **Risk: none** — test
env skips the reconciler entirely.

**[NEW-9, NEW-11] Job retry/discard policy.** `app/jobs/application_job.rb`
un-comments `retry_on ActiveRecord::Deadlocked` (polynomial backoff, 3 attempts)
and adds `discard_on ActiveJob::DeserializationError`. `app/jobs/funding_job.rb`
adds `discard_on ActiveRecord::RecordNotFound` — a position deleted between
enqueue and perform is not a retriable failure. **Risk: none** — `perform_now`
in specs does not trigger `retry_on` for the happy path.

### 2.3 Security

**[NEW-2] Non-root production container.** `Dockerfile` production stage creates
a dedicated `app` user (uid/gid 1001), chowns only `tmp/`, `log/`, `storage/`,
and runs Puma as that user. Previously the production image ran as root, so any
RCE executed with full container privileges. **Risk: none** — Docker-only.

**[NEW-3, NEW-4] SSL + DNS-rebinding defaults.** `config/environments/production.rb`
enables `config.assume_ssl` and `config.force_ssl` by default (both env-overridable
via `PAPER_EXCHANGE_ASSUME_SSL` / `PAPER_EXCHANGE_FORCE_SSL`), and adds an env-driven
`config.hosts` (`PAPER_EXCHANGE_ALLOWED_HOSTS`, comma-separated, defaults to permissive
so a first deploy to any hostname is not 403-blocked). `/up` and `/health` are exempt
from both the SSL redirect and host authorization. **Risk: none** — only affects
production env; dev/test/compose unaffected.

### 2.4 Observability

**[NEW-16] Deep health probe.** New `app/controllers/health_controller.rb` +
`GET /health` route (unauthenticated, NOT under `/api`) returns `200 {"status":"ok"}`
only when Postgres, Redis, and Solid Queue all answer, and `503 {"status":"degraded",
"checks":{...}}` otherwise. The existing `/up` stays as the shallow "did Rails boot"
probe for docker-compose. Point load balancers at `/health` so they stop routing
traffic to a replica with a dead Redis (which silently stops liquidations). **Risk:
none** — additive route + controller.

### 2.5 Data integrity

**[NEW-30, NEW-31] Foreign keys from every money table to `accounts(account_id)`.**
New migration `db/migrate/20261010120000_add_account_foreign_keys.rb` adds FKs from
`ledger_entries`, `paper_exchange_orders`, `paper_exchange_positions`, `risk_events`,
and `funding_payments` to `accounts(account_id)`. Previously the reference was
app-layer only (`MarginLedger.lock_margin!` does `Account.lock.find_by!`), so a
rogue AR update or SQL typo could write rows for a non-existent account and corrupt
the Reconciler's wallet derivation. `db/schema.rb` is bumped to version
`2026_10_10_120000` with the matching `add_foreign_key` calls so `db:test:prepare`
stays consistent. The `AccountsController#reset` deletion order
(funding_payments → trades → positions → orders → ledger) already respects child-
before-parent, so `NO ACTION` (the default) is safe. **Risk: low** — run on a clean
DB or backfill/repair orphan rows first (a query is in the migration comment).

### 2.6 Testing

**[NEW-17] Redis re-enabled in CI.** `.github/workflows/ci.yml` un-comments the
Redis service and sets `REDIS_URL`. Previously CI exercised the Redis-unavailable
degradation path (`MarkPriceStore`/`TickProcessor` rescue `Redis::BaseError` → nil)
instead of the real production path — the mark_prices / market_events / liquidation
specs were effectively testing degraded mode. **Risk: none** — config-only.

**[NEW-18] Funding idempotency regression spec.** `spec/jobs/funding_job_spec.rb`
adds a context asserting that `perform_now` called twice with the same `funding_time`
produces exactly one `FundingPayment` and one `FUNDING_FEE` ledger entry, and that a
different `funding_time` settles independently. The dedup mechanism (unique partial
index `index_funding_payments_dedup` + `find_or_initialize_by`) was previously
untested at the regression level. **Risk: none** — additive examples.

**[NEW-21] VixGateValidator spec.** New `spec/services/risk/vix_gate_validator_spec.rb`
covers the pass/reject boundary (inclusive at 20.0), the inert no-context path, and a
custom threshold. This was the only risk validator with no spec. **Risk: none** —
additive file.

**[NEW-16 spec] HealthController spec.** New `spec/controllers/health_controller_spec.rb`
pins the 200/503 contract and the unauthenticated property. **Risk: none** — additive.

### 2.7 Configuration

**[NEW-22, NEW-24] `.env.example` expanded.** Documents every env var the codebase
reads: `DATABASE_URL`, `REDIS_URL`, `RAILS_LOG_LEVEL`, `WEB_CONCURRENCY`,
`RAILS_MAX_THREADS`, `SOLID_QUEUE_IN_PUMA`, `JOB_CONCURRENCY`, all seven brokerage
schedule vars (`PAPER_EXCHANGE_BROKERAGE_FLOOR`, `PAPER_EXCHANGE_STT_DELIVERY`, etc.),
`PAPER_EXCHANGE_ORDER_TTL_MINUTES`, and the Dhan credentials. Previously only ~8 of
~20 env vars were documented. **Risk: none** — docs-only; placeholder values keep
the CI hex-secret guard happy.

### 2.8 Performance (additive, non-breaking)

**[NEW-38 partial] `MarkPriceStore.bulk_get`.** `app/services/market_data/mark_price_store.rb`
adds an `HMGET`-backed `bulk_get(symbols)` method so read paths that project many
positions can fetch all mark prices in ONE Redis round-trip instead of N. This is
additive — `PositionProjection#for_account` is left unchanged (it still calls `get`
per row) to avoid disturbing its spec; a follow-up can switch it to `bulk_get` once
the perf win is verified. **Risk: none** — new method, no callers changed.

### 2.9 Cleanup

**[N7] Dead `position_locked` variable exposed.** `app/controllers/api/accounts_controller.rb`
now renders `wallet.position_locked` alongside `wallet.locked`. The figure was already
computed (position-level `initial_margin` for open leveraged positions) but silently
discarded — the prior N7 fix renamed the variable without wiring the output. Now the
locked-margin split is fully reconcilable by callers. **Risk: none** — additive JSON
field; no existing spec asserts the exact wallet shape.

**[NEW-28] Removed `|| true` from Dockerfile `assets:precompile`.** A real precompile
failure is no longer masked. For an API-only app this is mostly harmless, but the
`|| true` could hide a genuine asset-pipeline break. **Risk: none** — Docker-only.

---

## 3. Recommended follow-up (requires a Ruby runtime to verify)

These are real production-readiness gaps that this pass **documents but does not
implement**, because verifying them needs `bundle exec rspec` (unavailable here)
or a gem/lockfile change.

### 3.1 High priority

| # | Action | Where | Why deferred |
|---|--------|-------|--------------|
| **NEW-1** | Add `rack-attack` rate limiting on `/api/*` and especially `POST /api/account/reset`. | `Gemfile` + initializer | Adds a gem → needs `bundle install` to update `Gemfile.lock`; can't do without Ruby. A leaked shared API key + no rate limit burns the broker. |
| **NEW-13** | Prometheus `/metrics` endpoint (orders/sec, liquidation enqueue latency, Redis outage count, reconcile drift, queue depth). | `Gemfile` + middleware | New gem + lockfile. A money system in production is currently unmeasurable. |
| **NEW-14** | Structured (JSON) logging via `lograge` + `lograge_json`. | `Gemfile` + production.rb | New gem. Current default Rails logging is ~6 lines/request and not machine-parseable. |
| **NEW-15** | Stamp `request.uuid` into `RiskEvent.details` and `LedgerEntry.payload` for forensic correlation. | `margin_ledger.rb`, `ledger.rb`, jobs | Touches the money-write hot path; needs spec verification. Today a misbehaving agent push that mass-liquidates leaves no forensic trail beyond the request log. |
| **S10** | Zeitwerk normalization: move `dcx:/usdm:` inflections to `config/initializers/inflections.rb`, delete the loader unregister + self-alias. | `config/application.rb`, `config/initializers/exchange_catalogs_loader.rb`, `binance_usdm_futures_catalog.rb` | Subtle load-order change; needs full suite + eager-load to verify. Listed in `memory.md §5` as open. |
| **S15** | Extract stateless engines from `PaperExchange` so the per-request `@books`/`@mutex` goes away (or make it a singleton). | `app/services/exchange/paper_exchange.rb`, `orders_controller.rb` | Architectural refactor touching the order hot path; needs the full integration suite (`trading_lifecycle_spec`, `paper_lifecycle_spec`, `liquidation_flow_spec`) to verify. Listed in `memory.md §5` as open. |

### 3.2 Medium priority

| # | Action | Where | Why deferred |
|---|--------|-------|--------------|
| **NEW-12 (full)** | Make `MarkPriceStore.set` return `nil` on Redis failure and have the controller 503 unconditionally (not just in production). | `mark_price_store.rb`, `mark_prices_controller.rb`, specs | The current implementation 503s only in production (test/dev keep the graceful-degradation path so specs run without Redis). The full fix changes `set`'s return contract and would require updating `mark_prices_controller_spec` expectations — needs `rspec` to verify. |
| **NEW-27** | Guard `db:prepare` in `bin/docker-entrypoint` with a Postgres advisory lock so multi-replica deploys don't race on `db:migrate`. | `bin/docker-entrypoint` | Bash + SQL change; recommended pattern is a separate `kamal app exec --reuse bin/rails db:migrate` pre-deploy hook instead. Single-replica default is safe today. |
| **NEW-34** | `Idempotency-Key` header convention on `POST /api/mark_prices`, `/api/funding_events`, `/api/market_events`, `/api/market_structure`. | controllers + initializer | API contract change; funding is already idempotent via `funding_time` but a retried market_events batch can double-enqueue ticks. Needs spec + OpenAPI work. |
| **NEW-32** | Backfill nulls then `change_column_null :ledger_entries, :balance_after, false`. | migration + reconciler | Needs a data backfill pass first; the column is nullable today. |
| **N4** | TTL on `MarkPriceStore` local cache so a stale in-process entry re-fetches from Redis after N seconds. | `mark_price_store.rb` | Switches `Concurrent::Hash` to a time-aware structure; needs spec verification that same-process reads still return fresh values. |
| **N8** | `SimpleCov.minimum_coverage` threshold + assert eager-load in CI. | `spec/support/simplecov.rb`, ci.yml | Setting a threshold without measuring current coverage first would either be too low (useless) or too high (breaks CI). Needs a baseline run. |
| **N10** | Re-baseline Indian brokerage rates vs current FY schedule (the constants are env-tunable but the defaults are stale and uncited). | `brokerage_calculator.rb` | Needs the current FY schedule; out of scope for a code review. |
| **NEW-39, 40, 41** | N+1 / hot-path query optimizations: pre-load positions in `Ledger.compute_unrealized_pnl`, throttle `LiquidationEngine.refresh_cache!`, consolidate `Reconciler` boot scan. | ledger.rb, liquidation_engine.rb, reconciler.rb, mark_prices_controller.rb | Touch hot paths; each needs perf measurement + spec verification. |

### 3.3 Lower priority / documentation

- **NEW-5** Request body size limit (`Rack::ContentLength` ceiling) — currently unbounded; a 100 MB JSON POST blocks a Puma thread.
- **NEW-7** Operator API-key rotation runbook (the single shared key has no documented rotation procedure).
- **NEW-19** Load/perf test (`k6` or `autocannon`) — throughput ceiling is unknown.
- **NEW-20** Migrate remaining 8 controller specs → request specs (`rules.md §6` preference).
- **NEW-23** Feature flags (`PAPER_EXCHANGE_FEATURE_*`) so v1.1 capabilities (`IndicatorEngine`, `CandleBuilder`, `GreeksService`) can ship dark.
- **NEW-25, 26** Kamal `deploy.yml` hardening: uncomment DB/Redis accessories, add `PAPER_EXCHANGE_API_KEY` to `env.secret`, set `REDIS_URL`.
- **NEW-33** Backup/restore runbook (`pg_dump`, WAL archiving, quarterly restore-test cadence).
- **NEW-35** API versioning: declare `/api/v1` canonical with `/api` as a deprecated alias.
- **NEW-36** `openapi.yaml` (or `rspec-openapi` generation) so the agent has a machine-readable contract.
- **NEW-37** `Content-Type` negotiation (`before_action :ensure_json_request` → 406 non-JSON `Accept`).
- **S7** Wire-or-remove the remaining unreachable strategy/market-data services (`IndicatorEngine` compute, `CandleBuilder`, `GreeksService`, `OptionChainService`, `OptionSelector`, `PaperExchange#market_event`, `BinanceUsdmFuturesCatalog.fetch_instruments`).

---

## 4. How to verify this branch

```bash
cd paper_exchange
cp .env.example .env
# Edit .env: regenerate RAILS_MASTER_KEY + SECRET_KEY_BASE + PAPER_EXCHANGE_API_KEY
docker compose up -d --build
docker compose exec api bundle exec rspec
```

CI (`.github/workflows/ci.yml`) now runs Redis alongside Postgres, so the
mark_prices / market_events / liquidation specs exercise the real Redis path.

## 5. Summary

The repo was already in strong shape — the seven ship-blocking issues from the
prior audit are all fixed, and the ledger discipline, risk-gate fail-closed
behavior, and immutable-ledger enforcement are genuinely well-engineered. This
hardening pass closes the operational gaps that remained: a consistent JSON
error envelope, fatal boot reconciliation, non-root container, SSL + host
hardening, a deep health probe, structural foreign keys, Redis in CI, and
regression specs for the previously-untested funding idempotency and VIX gate.
The larger refactors (rate limiting, metrics, Zeitwerk normalization, order-
book lifetime) are documented in §3 with concrete file targets for a follow-up
sprint that has a Ruby runtime available.
