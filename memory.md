# Memory — Project Memory & Context for paper_exchange

> **Primary reader:** AI developer. This is the **long-lived context file**. Last updated: 2026-09-25.
> **Update protocol (mandatory):**
> 1. Completed a task in `tasks.md` → flip its status, then append a one-line entry to §4 (Decisions) or §6 (Learnings) if non-obvious.
> 2. Fixed a bug → add a row to §5 (Bugs fixed) with root cause and regression-spec name.
> 3. Changed architecture/trust model → update `architecture.md` and note the change here.
> 4. Never delete history — append. Date every entry.

---

## 1. Current state (snapshot 2026-09-26, evening)

- **Phase:** Phase 0–5 core polish + v1.1 wiring complete (main @ `v1.0.0-audit-clean`): all 7 MUST closed; Phase 3 done; T5.1/T5.2/T5.4 (ledger immutability, event_type convention, cursor pagination) and T4.1b (market events + market structure + strategy signals endpoints) done on `feat/phase5-polish-wiring`. **Remaining:** T4.3/T4.4 housekeeping, T5.3 test gates, T5.5 spec migration, T5.6 N4/N10.
- **Auth:** `X-API-Key` = `PAPER_EXCHANGE_API_KEY` (401 otherwise; production fails boot without it). Credentials rotated — the old leaked master key can no longer decrypt `credentials.yml.enc`.
- **Test suite:** ~65 spec files / 310 examples — added in the last sprint: ledger immutability + event-type specs, pagination request spec, tick-processor stream specs (fake Redis), market-events/market-structure/strategy-signals request specs, auth spec now covers all 11 route groups.
- **Deployment story:** Docker Compose (dev) + Kamal 2. Redis required for mark prices AND the market-events tick stream. Reconciler runs at boot, skipped in test.
- **If you're reading this later, trust `tasks.md` statuses over this paragraph, and update this snapshot.**

## 2. Critical context — read before touching code

1. **Trust model (updated 2026-09-26):** the trading agent is *trusted* and owns market data (it pushes prices/funding). Auth is a shared operator token: `X-API-Key` must equal `PAPER_EXCHANGE_API_KEY` (M2 closed). Within that boundary, `X-Account-Id` selects the paper account. Per-account keys remain a roadmap item.
2. **`internal: true` / `reduce_only: true` skip margin + risk gates — INTENTIONAL (B3).** A liquidation force-close on an underwater account would fail its own margin check and deadlock forever. See §5.
3. **`LedgerEntry` is append-only — ENFORCED (N3 closed 2026-09-26):** `readonly?` raises on update/destroy of persisted rows; a BEFORE UPDATE trigger blocks even raw SQL. DELETE stays allowed ONLY for the account-reset wipe. Event types are SCREAMING_SNAKE_CASE (N2) — the model format-validates it.
4. **Wired vs unwired (updated 2026-09-26, T4.1b):** wired — `market_event`/`tick_processor` (Redis stream via `POST/GET /api/market_events`), `market_structure_engine` (DB-backed via `POST/GET /api/market_structure`), `strategy_engine` (read-only assess via `POST /api/strategy/signals`). Still unwired (Roadmap): `indicator_engine` compute, `candle_builder`, `greeks_service`, `option_chain_service`, `option_selector`, `vix_gate` data source (pass `context: {vix:}` to activate the validator).
5. **`PaperExchange` instances are per-request/per-job** (built in `orders_controller#create` and `liquidation_job.rb`) — the instance's `@books`/`Mutex` therefore guards nothing cross-request; cross-request pricing works via Redis `MarkPriceStore` (S15, decision pending T4.4).
6. **Money is `BigDecimal` over `decimal(36,18)`** — `.to_f` appears in places but only at simulation/serialization edges; never on stored money math (rule in `rules.md` §1).
7. **Test scaffolding quirk (removed 2026-09-26):** the `X-API-Key: test-api-key-123` → `test-account-1` remap was deleted with the auth change — X-API-Key is now the AUTH header, never an account-id source. Controller specs get the header injected globally in `rails_helper.rb`; request specs pass it explicitly.
8. **Env var drift resolved (S9, fixed 2026-09-26):** code reads the documented `PAPER_EXCHANGE_MAX_DRAWDOWN` (default 0.20; old `PAPER_EXCHANGE_MAX_DD` spelling still honored).
9. **API paths exist in both `/api` and `/api/v1`**, and mark/funding accept snake_case and kebab-case — legacy aliases, keep them.

## 3. Key invariants (must hold after any change)

| Invariant | Enforced by |
|-----------|-------------|
| Wallet balance == Σ ledger entries | `Ledger::MarginLedger` row locks + `Reconciler` at boot |
| Same `client_order_id` never fills twice | pre-check + unique index rescue-replay (`paper_exchange.rb`) |
| Same `(position, funding_time)` never settles twice | partial unique index on `funding_payments` |
| Reduce-only order never grows/flips a position | two-phase clamp (advisory + under-lock authoritative) |
| Margin lock + risk + fill are atomic; rejection releases the lock via rollback | H1 transaction in `submit_order` |
| Unlock never exceeds current `locked_margin` | clamp in `margin_ledger.rb` |

## 4. Decisions log (append-only)

| Date | Decision | Rationale | Where |
|------|----------|-----------|-------|
| 2025-06 | Rails 8.1 API-only, Postgres, Solid Queue/Cache, Puma | Rails-default modern stack; no Sidekiq dependency intended (gem still present — T4.2) | `Gemfile` |
| 2025-06 | All money `decimal(36,18)`; BigDecimal end-to-end | crypto-scale precision without float drift | `db/schema.rb` |
| 2025-06 | Agent owns market data; exchange owns accounting only | keeps the simulator honest and simple | `prd.md` §1, README |
| 2025-06 | Two-layer idempotency (pre-check + unique-index rescue-replay) | TOCTOU-safe under concurrency | `paper_exchange.rb` |
| 2025-06 | Append-only ledger + boot Reconciler | trust: wallet derivable from events; drift visible as `ADJUSTMENT` | `ledger/reconciler.rb` |
| 2025-06 | Funding idempotency via partial unique index `(paper_position_id, funding_time) WHERE funding_time IS NOT NULL` | right tool for at-least-once job redrive | migration 20260920140000 |
| ~2025-08 | H1: single transaction around lock+risk+fill; rollback IS the margin release | earlier bug: rejected orders leaked locked margin | `paper_exchange.rb:86-91` |
| ~2025-08 | B3: internal/reduce_only orders bypass margin+risk gates | liquidation self-deadlock (see §5) | `paper_exchange.rb:33-41` |
| ~2025-08 | Reduce-only two-phase clamp (advisory, then under lock) | concurrent closes raced the fill | `paper_exchange.rb:214-232` |
| ~2025-09 | B4: `test-api-key-123` remap gated to `Rails.env.test?` | public header remapped anyone to the test wallet | `api/base_controller.rb:12-17` |
| 2026-09-25 | Adopt audit backlog (`REVIEW.md`) as the stabilization roadmap | 7 must-fix defects, all small targeted fixes | `tasks.md` |
| 2026-09-25 | Auth approach: shared bearer token first (per-account keys deferred) | matches single-operator deployment story | `tasks.md` T1.2, `prd.md` non-goals |
| 2026-09-26 | T1.2 executed: `X-API-Key` = `PAPER_EXCHANGE_API_KEY` (constant-time compare, 401, boot-fail in production); X-API-Key no longer an account-id source | closes M2 with the minimum option; B4 scaffolding branch removed with it | `api/base_controller.rb`, `config/initializers/api_authentication.rb` |
| 2026-09-26 | T2.3 executed: RiskManager decides-only; rejection events persisted in submit_order's post-rollback rescue via `RiskCheckFailedError`; evaluation errors fail CLOSED as `RISK_EVALUATION_ERROR_REJECTED` | events created inside the doomed transaction were rolled back with it (M5) | `risk_manager.rb`, `paper_exchange.rb` |
| 2026-09-26 | T2.1 executed: position upsert locks rows + savepoint + one retry on RecordNotUnique; partial unique index for NULL-dimension contracts | SELECT FOR UPDATE doesn't block a concurrent insert of a missing row — the index arbitrates, the savepoint makes the violation recoverable (M4) | `position_manager.rb`, migration 20260926100000 |
| 2026-09-26 | T4.1 decided (option b-lite): keep unwired services in place, mark them Roadmap in the README feature table; wire-or-remove deferred to a v1.1 sprint | moving `app/services/strategy/*` etc. to a roadmap/ namespace changes Zeitwerk paths for zero user value; the README now tells the truth about what runs | README "Status", `tasks.md` T4.1 |
| 2026-09-26 | T4.2 executed: sidekiq gem removed | never referenced — Solid Queue adapter everywhere, no worker configured; pure supply-chain surface | `Gemfile` |
| 2026-09-26 | T5.1+T5.2 executed: ledger immutability enforced (readonly? + BEFORE UPDATE trigger, DELETE allowed for reset); event_type = SCREAMING_SNAKE_CASE with data migration + format validation | N3/N2 — convention became enforcement; the Reconciler's replay assumption is now protected at two layers | `ledger_entry.rb`, `ledger/immutability.rb`, migrations 20260926120000/120001 |
| 2026-09-26 | Trigger DDL lives in ONE shared module (`Ledger::Immutability`); migration installs it in dev/prod, `spec/support/ledger_immutability.rb` re-installs it on schema-loaded test DBs in `before(:suite)` (after `maintain_test_schema!`) | schema.rb cannot express triggers — without the shim, CI's `db:test:prepare` DB would silently lack the enforcement the specs assert | `spec/support/ledger_immutability.rb` |
| 2026-09-26 | T5.4 executed: list endpoints paginate via keyset `(sort_column, id) DESC`, envelope `{data, next_cursor}`; `placed_at` made NOT NULL (backfilled) so the keyset order is total; tampered cursor = 400, not 500 | N6 — silent caps truncated history; the envelope is the only sanctioned wrapper (design.md §1 updated) | `api/cursor_pagination.rb`, migration 20260926130000 |
| 2026-09-26 | T4.1b executed: market events → capped Redis stream (`TickProcessor` rebuilt class-level, MarkPriceStore-style resilience; Redis down = loud 503); market structure → DB-backed engine (the in-memory hash never survived a request); strategy signals → `StrategyEngine#assess`, read-only run of the same RiskManager gate (decide-only per M5), `Signal` gained `leverage` (default 1 = conservative full-notional) | wire the roadmap modules the audit kept as scaffolding; assessment never mutates state — submission stays `POST /api/orders` | `market_events_controller.rb`, `market_structure_controller.rb`, `strategy_controller.rb` |
| 2026-09-26 | Pagination envelope accepted as the ONE list-endpoint wrapper (breaking change from bare arrays); in-repo consumers checked before switching (smoke tests only POST orders; HTML sim doesn't parse lists) | agent-facing honesty (no silent truncation) beats the bare-array habit | `design.md` §1/§2 |

## 5. Bugs fixed (historical — from in-code comment trails + regression specs)

House style: fixed bugs get a short ID (`B1…B6`, `H1`) and a `(Bn regression guard)` spec. **Keep this convention.**

| ID | Bug (what happened) | Root cause class | Fix |
|----|--------------------|--------------------|-----|
| B1 | Position-limit validator passed accounts at/over the limit | boundary condition (`>=` vs `>`) | `position_limit_validator` + regression spec |
| B2 | Fractional crypto quantity / fractional notional escaped the `MAX_POSITION_VALUE` cap | integer-only assumptions in validation | validator handles fractional qty/notional + spec |
| B3 | **Liquidation self-deadlock:** force-close order needed a fresh margin lock on an underwater account → rejected by the risk engine that triggered the liquidation → position stuck, job retried forever | gate applied to its own remediation | `internal: true` (+ `reduce_only`) skips margin/risk gates for liquidation closes |
| B4 | Anyone hitting the public API with `X-API-Key: test-api-key-123` was silently mapped to the `test-account-1` wallet | test scaffolding leaked to prod behavior | remap gated with `Rails.env.test?` |
| H1 | Rejected orders leaked `locked_margin` (lock persisted, no release on the rejection path) | lock and business op in separate transactions | one transaction: lock+risk+fill; rollback releases the lock; outer rescue persists `rejected` |
| — | Reduce-only order could grow/flip a position when racing a concurrent close | TOCTOU between check and fill | advisory clamp pre-order + authoritative re-read under row lock in the fill transaction |
| — | Funding job double-charged on redrive | no dedup key | partial unique index + insert-rescue |

**Open (not yet fixed):** S10 (Zeitwerk normalization, T4.3), S15 (order-book lifetime, T4.4), N4 (MarkPriceStore TTL), N8 (test gates, T5.3), N10 (brokerage re-baseline) — see `tasks.md`. All MUSTs M1–M7 and the rest of S/N findings are closed with regression specs.

## 6. Key learnings (cite these when the pattern reappears)

- **Postgres unique indexes treat NULLs as distinct** → a composite unique index over nullable option-dimension columns enforces nothing for EQUITY/CRYPTO contracts; use a partial expression index (`WHERE … IS NULL`) or sentinels. (M4)
- **`SELECT … FOR UPDATE` on a missing row doesn't block concurrent inserts of that key** → pair row locks with `RecordNotUnique` rescue + bounded retry. (M4 fix)
- **`params` values are always Strings**; `Integer == String` is silently `false` in Ruby → the M7 class of always-404 bugs. Compare via `.to_s` or query by column.
- **`[].` destructuring yields `nil`** → `passed, rejected = []` makes `rejected` nil → `Array(nil).any?` is false → fail-open gates. Destructure defensively; risk gates fail **closed**. (M5)
- **Writes inside a transaction you then roll back vanish** — audit events must be persisted after the rollback (rescue path) or on a separate connection. (M5)
- **Transactional fixtures mask post-rollback write assertions** — use `use_transactional_tests = false` + cleanup, or a second DB connection, when testing that class. (M5 spec)
- **`"garbage".to_f == 0.0`** — unvalidated numeric input becomes a valid-looking zero; in a leveraged system that's a mass-liquidation primitive. Validate with `Float(x, exception: false)` + `.finite?` + bounds at the controller. (M3)
- **`Float::INFINITY` is not valid JSON** under Oj strict modes — cap or stringify non-finite metrics. (S14)
- **A unique index is the idempotency mechanism; the pre-check is just UX** — the rescue-replay dance is the actual guarantee (see `client_order_id`).
- **schema.rb cannot express triggers/rules** — when enforcement lives in the DB, a schema-loaded test DB (`db:test:prepare`, the CI path) lacks it. Share the DDL from one module and re-install it in `before(:suite)` (require-time is TOO EARLY: rails_helper runs `maintain_test_schema!` after loading spec/support, and a schema reload drops triggers). (N3)
- **redis-rb 6.0 stream API:** `xadd(key, entry, id:, maxlen:, approximate:)` and — mind the argument order — `xrevrange(key, range_end = '+', start = '-', count:)`; exclusive continuation is `xrevrange(key, "(<id>", '-', count:)`. CI has no Redis: stub the service class in request specs, but pin the real semantics against a fake in unit specs (CI stubs would hide a signature error). (T4.1b)
- **`MarketEvent` values must be strings for `xadd`** — nil values crash the command; compact them out and serialize timestamps as ISO8601(6).

## 7. Environment & ops facts

- **Redis is required** (`MarkPriceStore`); Solid Queue/Cache are DB-backed (no extra infra).
- **`docker-compose.yml` currently hardcodes the leaked master key as a default** (until T0.1 — after T0.1 a missing key must fail boot loudly).
- `bin/ci` runs the local CI suite (config via `config/ci.rb`): setup → rspec → rubocop → brakeman → bundler-audit. CI runs RSpec against a Postgres service.
- TS smoke suites (`smoke-test.ts`, `smoke-test-simulation.ts`) run **against Docker, not in CI** — they are the executable version of the accounting invariants table; keep them updated when response shapes change.
- Kamal deploy config in `config/deploy.yml`; `.env` via dotenv-rails; `RAILS_MASTER_KEY` from environment (never commit — M1).
- Liquidation cache blind window: positions opened after the last mark-price push for their symbol are unmonitored until the next push (design trade-off, N9 — document, don't "fix", unless asked).

## 8. Review & audit history

| Date | Event | Artifact |
|------|-------|----------|
| 2026-09-25 | Full six-dimension audit (correctness, simplicity, architecture, security, performance, scope) using the `ruby-agent-skills` pack (Iteration 79; 6 skills + 4 pattern guides) | `REVIEW.md` — 7 MUST / 15 SHOULD / 10 NICE, all with file:line evidence + fix sketches; includes meta-evaluation of the skill pack itself (verdict: content correct, gaps: money-math skill, enum guards, ledger patterns, audit mode, 352-pattern navigability) |
| 2026-09-25 | M1 repo-side purge + CI secret guard, M7 positions#show fix, AI-dev docs, CI recovery, 11 dependabot bumps consolidated and merged (PRs #30–#33) | git history (PR #33 = develop → main consolidation) |
| 2026-09-26 | Audit backlog executed end-to-end on `feat/audit-clean-v1`: M1 credential rotation, M2 auth, M3 boundary validation, M4 position locking + partial unique index, M5 fail-closed risk gate + post-rollback events, M6 liquidation outcome assertion, S1–S15 + N-tier fixes (Phase 0–4); ~35 new regression specs | this branch; `tasks.md` per-task evidence |

Skill-pack meta-verdict in one line: **content technically sound and Rails 8.1-current; improve coverage (money/BigDecimal, enum state machines, ledger/reconciliation patterns) and navigability (pattern index), not correctness.**
