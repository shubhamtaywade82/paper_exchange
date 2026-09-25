# Tasks — Development Plan for paper_exchange

> **Primary reader:** AI developer. Last updated: 2026-09-25.
> **Source of truth for the backlog:** the 2026-09-25 full audit (`REVIEW.md`) — 7 MUST (M1–M7), 15 SHOULD (S1–S15), 10 NICE (N1–N10) findings, each with file:line evidence and fix sketches. This file sequences them into executable tasks.
> **Update protocol:** when you start a task set status `In Progress`; when done set `Done`, check off acceptance criteria, and append any decision/learning to `memory.md`. Add new tasks at the bottom of their phase — never reorder closed items.

**Status:** `TODO` · `In Progress` · `Done` · `Blocked` (state blocker in Notes)
**Priority:** `P0` = security/data-integrity emergency · `P1` = broken contract or race on money path · `P2` = correctness debt · `P3` = hygiene/polish
**Current phase: Phase 0 — Security emergency.** (MVP features are Done; see §Done baseline.)

---

## Phase 0 — Security emergency (do today; ~half a day)

- [ ] **T0.1 · P0 · In Progress — Rotate the leaked master key & purge committed secrets (audit M1)** — repo-side purge + CI guard pushed on branch `fix/audit-m1-m7` (PR pending). **Remaining operator steps:** rotate credentials (`bin/rails credentials:edit`/`reset` with a fresh key — requires Rails runtime), keep the new key only in uncommitted `.env`/Kamal secrets, and treat the old key as leaked forever (it remains in git history).
  Evidence: `.env.example:4` ships a real `RAILS_MASTER_KEY` that **decrypts `config/credentials.yml.enc`** (verified cryptographically); `docker-compose.yml` hardcodes it as the `:-` default; key exists in git history.
  Steps: 1) `bin/rails credentials:edit` → new `secret_key_base` (`openssl rand -hex 64`); 2) new master key kept only in uncommitted `.env`/Kamal secrets; 3) `.env.example` → placeholders, delete the compose `:-default`; 4) add secret-pattern CI guard (gitleaks or grep of 64-hex) next to brakeman.
  **Accept when:** committed key can no longer decrypt the new credentials file; `docker compose up` without `.env` fails loudly; CI guard catches a planted 64-hex string; `SECRET_KEY_BASE` in `.env.example` is a placeholder.

- [ ] **T0.2 · P0 · TODO — Validate mark-price & funding inputs at the boundary (audit M3)**
  Evidence: `mark_prices_controller.rb:17-23` — `"abc".to_f == 0.0` triggers mass false liquidations; `funding_events_controller.rb` — unbounded `funding_rate.to_f`, `funding_time` casts to `nil` (bypasses dedup index).
  Fix: `Float(price, exception: false)` + `.finite?` + `> 0` + sane ceiling; funding rate bounded (`abs <= 0.05`/settlement); unparseable `funding_time` → 422 (per `rules.md` §1).
  **Accept when:** regression spec posts `prices: { "BTCUSDT" => "garbage" }` → no `LiquidationJob` enqueued, prior price retained, 422/skip; garbage `funding_rate` rejected; `funding_time: "not-a-time"` rejected with 422.

## Phase 1 — Broken contracts & trust boundary (this week)

- [ ] **T1.1 · P1 · In Progress — Fix `GET /api/positions/:id` (audit M7)** — fix + regression specs pushed on branch `fix/audit-m1-m7` (PR pending): `PositionProjection#for_id(account_id, id)` queries by id AND account (foreign id → plain 404, no existence oracle) and projects one row; controller early-returns 404.
  Evidence: `positions_controller.rb:10` — `Integer == String` comparison is always false → every request 404s.
  Fix: match on `p[:id].to_s == params[:id]`, or better: query `PaperPosition.find_by(id: params[:id], account_id: @account_id)` + project the single row.
  **Accept when:** request specs cover valid id (200, projected shape), foreign-account id (404, no existence oracle), unknown id (404). Endpoint listed as consumable in `design.md` §2 (remove the ⚠).

- [ ] **T1.2 · P1 · TODO — Minimal authentication: shared bearer token (audit M2, minimum option)**
  Scope: single-operator trust model per `prd.md` §3 — `X-API-Key` must equal `ENV["PAPER_EXCHANGE_API_KEY"]` via `before_action` in `Api::BaseController`; 401 otherwise; fail boot in production if unset; tighten CORS (`origins "*"` → agent origin or drop rack-cors — N5).
  **Accept when:** unauthenticated request to every route under `/api` → 401; authenticated flow unchanged; README documents the trust model; spec per controller is unnecessary (one request spec per route group suffices).
  **Out of scope:** per-account API keys (roadmap; note in `memory.md` if the decision changes).

- [ ] **T1.3 · P2 · TODO — Controller hygiene prerequisite (audits S8 + S11)**
  `AccountsController < Api::BaseController` (currently `ApplicationController`), delete duplicated `set_account`; wrap `POST /api/account/reset` five-table wipe in `Account.transaction`.
  **Accept when:** zero duplicated account-resolution logic; reset spec asserts all-or-nothing (simulate failure mid-wipe → nothing deleted).

## Phase 2 — Money integrity races & risk-gate correctness (next)

- [ ] **T2.1 · P1 · TODO — Position upsert: row lock + NULL-safe unique index + retry (audit M4)**
  Fix: `.lock.where(contract_scope)` inside the fill transaction; partial unique expression index `WHERE option_type IS NULL AND strike_price IS NULL AND expiry_date IS NULL` on `(account_id, symbol, instrument_type)`; `rescue ActiveRecord::RecordNotUnique` → retry once (idempotency-rescue precedent at `paper_exchange.rb`).
  **Accept when:** concurrency spec (two threads, same contract from flat, join) → exactly one position row, quantity = sum; duplicate-row attempt raises the unique violation and is handled.

- [ ] **T2.2 · P1 · TODO — Margin sync under the same lock (audit S6)**
  Verify (and spec) that `MarginEngine.sync_position!` computes `delta` from the **locked** position instance after T2.1; fix ordering if the lock is taken after the read.
  **Accept when:** concurrency spec on double-fill same contract → `locked_margin` exactly one delta apart from baseline, `initial_margin` last-writer-wins eliminated.

- [ ] **T2.3 · P1 · TODO — Risk gate: fail closed + persist rejection events post-rollback (audit M5)**
  Fix: `rescue` in `risk_manager.rb` re-raises or returns synthetic `RISK_EVALUATION_ERROR_REJECTED` (never `[]`); move `RiskEvent.create!` for rejections into `submit_order`'s post-rollback rescue path (which already persists `order.rejected!`).
  **Accept when:** spec with a raising validator → order NOT filled; spec with a tripped validator → `*_REJECTED` `RiskEvent` rows exist after the request (with `use_transactional_tests = false` or second-connection assertion); rewrite `risk_manager_spec.rb` without mocked validators.

- [ ] **T2.4 · P1 · TODO — Liquidation outcome assertion + cache re-arm (audit M6)**
  Fix in `liquidation_job.rb`: after `submit_order`, require `order.status == "filled"` (or `position.reload.quantity.zero?`) before emitting `POSITION_LIQUIDATED`; on non-filled emit `LIQUIDATION_FAILED` with `rejection_reason` + call `Risk::LiquidationEngine.refresh_cache!` to re-arm; let retry policy re-drive.
  **Accept when:** spec clears `MarkPriceStore` before performing the job → `LIQUIDATION_FAILED` (not `POSITION_LIQUIDATED`), cache still armed, position still open.

## Phase 3 — State machine & config hygiene (housekeeping sprint)

- [ ] **T3.1 · P2 · TODO — Guarded order-state transitions (audits S1 + N1)** — `cancel!` precondition `pending? || open?` (raise `StateError` otherwise); same for `expired!`/`open!`; load with `.lock` in `cancel_order`; model spec asserting the full legal-transition table.
- [ ] **T3.2 · P2 · TODO — Order expiry actually works (audit S2)** — add missing `expired_at` column (migration; `expire_order` currently raises `UnknownAttributeError`); wire Solid Queue recurring sweep in `config/recurring.yml`: expire `open` orders older than N minutes with `locked_margin > 0` (releases margin).
- [ ] **T3.3 · P2 · TODO — Env-var & docs alignment (audit S9)** — code reads `PAPER_EXCHANGE_MAX_DD` default 0.10 vs documented `PAPER_EXCHANGE_MAX_DRAWDOWN` default 0.20; align `PAPER_EXCHANGE_MARGIN` default (100000 vs 10000); fix README slippage claim (execution_price fills bypass slippage). Spec asserts the documented var changes validator behavior.
- [ ] **T3.4 · P2 · TODO — `database.yml`: `max_connections` → `pool:` (audit S13)** — key is silently ignored today; `pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>`.
- [ ] **T3.5 · P2 · TODO — Margin validator vs actual lock agreement (audit S3)** — pick option (b): validator checks full notional for unleveraged instruments; fix the comment; spec: 50%-of-balance equity order → clean 422 pre-mutation (not 402).
- [ ] **T3.6 · P2 · TODO — No silent zero-PnL (audit S4)** — remove bare `rescue; 0.0` in `ledger.rb#compute_realized_pnl`; log-and-raise per `rules.md` §1.
- [ ] **T3.7 · P2 · TODO — Net sell proceeds vs charges (audit S5)** — `credit = [proceeds - charges, 0].max`, remainder into `debit`; spec: cheap option sell no longer 422s.
- [ ] **T3.8 · P3 · TODO — Faraday timeouts (audit S12)** — catalogs: `timeout: 5, open_timeout: 2` + `faraday-retry`.
- [ ] **T3.9 · P3 · TODO — Performance memoization + Infinity guard (audit S14)** — one `PortfolioProjection.summary` call in `performance_metrics.rb`; serialize/cap `profit_factor`.

## Phase 4 — Scope honesty (decision-heavy; needs operator input)

- [ ] **T4.1 · P2 · TODO — Unwired services: wire or remove (audit S7)** — ~15 files with no runtime callers (`strategy/*` entire namespace, `tick_processor`, `candle_builder`, `greeks_service`, `option_chain_service`, `vix_gate`, `market_event`, `expire_order`, `BinanceUsdmFuturesCatalog.fetch_instruments`). Options: (a) wire intended paths (e.g. `market_event` → `POST /api/market_events`), (b) move to `app/services/roadmap/` + trim README feature table. **This is a scope decision — record it in `memory.md` before executing.**
- [ ] **T4.2 · P3 · TODO — Remove unused `sidekiq` gem** — adapter is Solid Queue everywhere; pure supply-chain surface.
- [ ] **T4.3 · P3 · TODO — Zeitwerk normalization (audit S10)** — inflections → `config/initializers/inflections.rb`; delete explicit requires + loader unregister in `exchange_catalogs_loader.rb`; rename catalog class/file to kill the self-alias. Add eager-load smoke check to CI (pairs with T5.3).
- [ ] **T4.4 · P3 · TODO — Order-book lifetime decision (audit S15)** — either extract stateless engines and drop the per-instance `@books`/`Mutex`, or make the book a process-level singleton fed by a real endpoint. Update the class comment either way.

## Phase 5 — Background polish (opportunistic, pair with test migration)

- [ ] **T5.1 · P3 · TODO — Enforce ledger immutability (N3)** — `readonly?` guard on `LedgerEntry` (+ note); optional PG rule blocking UPDATE/DELETE.
- [ ] **T5.2 · P3 · TODO — Normalize `event_type` casing (N2)** — uppercase everywhere incl. legacy `"trade"`; model format validation.
- [ ] **T5.3 · P3 · TODO — Test gates (N8)** — `SimpleCov.minimum_coverage`; CI eager-load check (`Rails.application.eager_load!` smoke).
- [ ] **T5.4 · P3 · TODO — Cursor pagination (N6)** — orders/ledger/risk_events on `(occurred_at, id)`; document caps meanwhile.
- [ ] **T5.5 · P3 · TODO — Controller specs → request specs** (migration, opportunistic per file touched).
- [ ] **T5.6 · P3 · TODO — Remaining N-tier** — N4 MarkPriceStore TTL · N7 dead `locked_total` var · N9 README liquidation-cache blind-window note · N10 re-baseline brokerage rates vs current FY schedule.

---

## Done — MVP baseline (feature work complete; see `prd.md` §4)

Orders with two-layer idempotency · margin wallet under row locks · contract-scoped positions · Redis mark prices · two-phase liquidation pipeline · idempotent funding · append-only ledger + boot reconciler · risk validators · read endpoints · Indian F&O charges · Docker/Kamal/CI toolchain · TS smoke invariant suites.

## Blocked / deliberately deferred

- Per-account API keys (needs multi-operator requirement — `prd.md` non-goal).
- WebSocket streaming (non-goal for MVP).
- Wiring `strategy/*` (blocked on T4.1 decision).

## Release checkpoint: "audit-clean v1"

Exit bar (from `prd.md` §7): T0.x–T2.x all Done (M1–M7 closed with regression specs) · Phase 3 ≥ 80% · T4.1 decision recorded · CI includes secret scanning. Then tag `v1.0.0-audit-clean` and update `memory.md`.
