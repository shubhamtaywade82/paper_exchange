# Rules — Coding Rules & Guidelines for paper_exchange

> **Primary reader:** the AI developer. These rules are **constraints, not suggestions**. Many exist because a 2026-09-25 audit (`REVIEW.md`) found the opposite behavior as a live defect — the "why" is cited per rule.
> Companion files: `architecture.md` (structure) · `design.md` (API surface) · `memory.md` (decisions).

---

## 0. Non-negotiables (read first)

1. **Money is `BigDecimal` end-to-end.** DB columns are `decimal(36,18)`. Never introduce `Float` arithmetic on stored money; convert at serialization boundaries only. Never return a fabricated number from a financial computation.
2. **`LedgerEntry` is append-only.** No `update`, no `delete`, no bulk destroy outside the documented dev reset. The Reconciler's correctness depends on immutability. (Enforcement gap tracked as N3.)
3. **Every wallet movement goes through `Ledger::MarginLedger`** under `Account.lock`. Never write `account.update_columns(balance: …)` directly.
4. **The transaction boundary in `submit_order` (H1) is load-bearing.** Margin lock + risk + fill must stay atomic; the rollback IS the margin release on rejection. Do not split it or "simplify" it without a written plan in `memory.md`.
5. **`internal: true` / `reduce_only: true` skipping the margin gate is intentional** (B3 liquidation self-deadlock fix). Do not make internal orders require margin.
6. **Don't build on unwired code.** `app/services/strategy/*` and the unwired `market_data/*` services (see `architecture.md` §7) have no runtime callers. Adding callers to them is a scope decision (S7), not a refactor.

## 1. Money & numerics

| Rule | Why (evidence) |
|------|----------------|
| Validate **all** external numeric input at the controller boundary: `Float(x, exception: false)` (or BigDecimal with exception), then check `.finite?`, positive, and a sane bound — reject with 422, never `.to_f` params directly | M3: `"abc".to_f == 0.0` in `MarkPricesController` can mass-liquidate every long on a symbol |
| Never let non-finite floats reach serialization (`Float::INFINITY`, `NaN`) — cap or stringify first | S14: `profit_factor` can be `Infinity` → invalid JSON under Oj |
| Rounding happens **once**, at the persistence boundary, with `BigDecimal#round(n)` using a fixed mode; no intermediate rounding | Consistency of ledger vs. cached equity |
| Sell proceeds/charges must be netted so no ledger field goes negative (`credit = [proceeds - charges, 0].max`) | S5: cheap options currently fail the whole order on negative credit |
| Never `rescue` inside a money computation and return a default value | S4: `compute_realized_pnl` returns `0.0` on any error and it gets **persisted** to the account row |

## 2. Concurrency & transactions

| Rule | Why |
|------|-----|
| **Lock before read-modify-write.** Any upsert on `paper_exchange_positions` or margin-delta computation must take the row lock (`scope.lock`) *before* reading current state | M4/S6: `PositionManager.apply!` and `MarginEngine.sync_position!` races → dropped fills / double-locked margin |
| A unique index backing an upsert must be **NULL-safe**: partial expression index `WHERE dim IS NULL …` for the NULL-dimension contracts, or sentinel non-NULL values | M4: Postgres treats NULLs as distinct → duplicate EQUITY/CRYPTO_PERPETUAL position rows |
| `SELECT … FOR UPDATE` on a missing row doesn't block concurrent inserts → pair it with `rescue ActiveRecord::RecordNotUnique` + one retry (the pattern already used for `client_order_id`) | M4 fix spec; in-house precedent at `paper_exchange.rb` idempotency rescue |
| Audit/observability writes that must **survive** a business-transaction rollback (e.g. rejection `RiskEvent`s) are written **after** the rollback, in the rescue path — never inside the doomed transaction | M5: rejection events currently vanish |
| Concurrency regression specs (two threads, same contract, join, assert one row + summed qty) ship **with** any money-path change | No concurrency specs existed; that's how M4 shipped |

## 3. Error handling

- **Fail closed on risk/safety paths.** If a risk validator raises, the order must NOT proceed. Log loudly, re-raise or return a synthetic `*_REJECTED` event. (M5: today `rescue => []` silently disables all risk checks.)
- **No bare `rescue`** anywhere; no `rescue => e` without either handling, logging, or re-raising. Narrowest exception class at the boundary that can actually act on it.
- **Controller error mapping is fixed** (see `design.md` §3): `OrderValidationError → 422`, `ArgumentError → 400`, `Ledger::InsufficientMarginError → 402`, missing resource → `404`, unknown → log + `500 "Internal error"`. Don't invent new shapes.
- **Status transitions are guarded**: `cancel!` only from `pending`/`open`; never overwrite a `filled` order's status (S1). Add a precondition raise (`StateError`) inside the transition method.
- Services raise typed errors; controllers translate. Services never render.

## 4. Coding standards & naming

- **Style:** `rubocop-rails-omakase` (`bin/rubocop`) is the arbiter. Run it before claiming done.
- **Frozen string literals** and Ruby 3.x syntax; keyword args for service entry points (`submit_order(attrs, internal: false, reduce_only: false)` style).
- **Naming:**
  - Models namespaced `PaperExchange::*` (tables `paper_exchange_*`) — keep new trading models in that namespace to avoid collisions.
  - Service suffixes mean things: `*Validator` (pure, raises), `*Engine` (stateful domain logic), `*Manager` (orchestrator over models), `*Job` (Solid Queue), `*Projection` / `*Calculator` (read-side, pure).
  - Env vars: `PAPER_EXCHANGE_` prefix. **The name in code must equal the name in `.env.example` and README** (S9 drift: `MAX_DRAWDOWN` vs `MAX_DD`).
- **Zeitwerk:** no explicit `require` of autoloaded files; inflections go in `config/initializers/inflections.rb` (not `after_initialize`); no loader unregistering; no self-aliases (all S10).
- **JSON keys are snake_case**; enums are lowercase symbols/strings (`order_kind`, `status`); `LedgerEntry.event_type` and `RiskEvent.event_type` are UPPERCASE event names (⚠ `trade` currently lowercase — N2 will normalize; don't add new lowercase ones).
- **Comments that explain *why*** (the B1–B6/H1 trail in `exchange/` is the house style) — keep them when refactoring; they are the bug-history record.
- **Dead code policy:** before deleting anything, grep callers across `app/ config/ db/ spec/`; before wiring anything unwired, that's a scope decision → `tasks.md` first.

## 5. Libraries: use / avoid

**Use (already in the stack):**
- Rails 8.1 defaults: Solid Queue, Solid Cache, `config/ci.rb` local CI. Do not add Sidekiq/Redis-queue backends.
- `dry-validation` for any new external input schema (pattern: `Exchange::OrderValidator`).
- `Oj` (already the JSON backend).
- Faraday **with explicit timeouts** (`timeout: 5, open_timeout: 2`) + `faraday-retry` for any outbound HTTP (S12).
- FactoryBot + RSpec; VCR/WebMock for external HTTP in specs.

**Avoid / do not add:**
- `sidekiq` — unused; scheduled for removal (T4.2).
- Money/float helpers that do Float math (e.g. `Float#round` on money paths).
- AASM or state-machine gems for the order enum — guard transitions with plain preconditions; the audit's S1 fix is deliberately minimal.
- New DB-backed gems for things Rails 8.1 ships (cache, queue, cable).
- Any gem touching `LedgerEntry` writes other than `Ledger::*` services.

## 6. Testing rules

1. **Request specs over controller specs** for new/moved endpoint coverage (`get "/api/orders", headers:`) — routing + params + serialization are the contract the agent consumes.
2. **Never mock the thing under test's collaborators in risk specs.** `risk_manager_spec.rb` mocking all validators is exactly why M5 shipped invisible. Use a real account + a signal that trips one real validator.
3. **Every bug fix ships with a regression spec** named for the bug class (house style: `(B2 regression guard)` — keep the convention, e.g. `(M3 regression guard)`).
4. When asserting writes that must survive a rollback (M5 class), use `self.use_transactional_tests = false` + explicit cleanup, or assert over a second DB connection.
5. Money-path changes require a **concurrency spec** (see §2).
6. External HTTP in specs goes through VCR cassettes; never hit real exchanges in CI.
7. Keep SimpleCov green; a coverage threshold is planned (N8) — don't land code that drops coverage.

## 7. Constraints for the AI (do-not-do list)

- ❌ Do not "helpfully" add authentication middleware, pagination, or new endpoints without a task in `tasks.md` (scope decisions, sequenced deliberately).
- ❌ Do not modify `LedgerEntry` rows retroactively, even to "fix" data — write a correcting `ADJUSTMENT` entry instead (Reconciler pattern).
- ❌ Do not remove or bypass the `PositionGoneError` / reduce-only clamp logic — it prevents double-close races.
- ❌ Do not change API response shapes or status codes without bumping the note in `design.md` §3 — the agent depends on them.
- ❌ Do not commit anything that looks like a secret (64-hex, `-----BEGIN`, tokens). `.env.example` holds placeholders only (M1).
- ❌ Do not add callers into `app/services/strategy/**` or the unwired `market_data/*` services (S7 decision pending).
- ❌ Migrations are additive by default; money column changes require `precision: 36, scale: 18`.

## 8. Definition of done (per task)

- [ ] Code follows §1–§5; `bin/rubocop` clean; `bin/ci` green locally.
- [ ] Regression spec(s) per §6 named for the bug/task ID.
- [ ] `tasks.md` status updated; `memory.md` appended (decision or learning) if the change is non-obvious.
- [ ] No new MUST/SHOULD-class behavior introduced (self-check against `REVIEW.md` taxonomy).
- [ ] README touched if user-visible behavior or env vars changed.
