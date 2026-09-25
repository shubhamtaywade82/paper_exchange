# PRD — paper_exchange

> **Primary reader:** the AI developer working on this repo. **Human reader:** the operator.
> Last updated: 2026-09-25. Companion files: `architecture.md` (how it works) · `rules.md` (how to code here) · `tasks.md` (what's next) · `memory.md` (state & decisions).

---

## 1. Overview

**paper_exchange** is a self-hosted, API-only **paper-trading broker** built for an autonomous trading agent. The agent owns market data (it decides what prices exist); paper_exchange owns **accounting truth**: orders, fills, margin, positions, funding, liquidations, and an append-only, reconcilable ledger.

- **What it simulates:** a derivatives/equities broker with leverage, margin locking, mark-price liquidations, per-position funding settlements, and Indian F&O + crypto perpetual instrument models.
- **What it is:** a Rails 8.1 API-only service (no UI), single-operator, deployed via Docker/Kamal, PostgreSQL + Redis + Solid Queue.
- **One-liner:** *a simulated broker with real broker discipline — margin, funding, liquidation, and a ledger you can rebuild the wallet from.*

## 2. Problem statement

1. Testing a trading agent against a real exchange risks real money, hits rate limits, and can't be reset.
2. Off-the-shelf paper trading (TradingView, exchange testnets) either lacks derivatives mechanics (margin locking, funding, liquidation engines) or lacks an agent-friendly API (idempotent order submission, bulk price pushes, machine-readable ledger export).
3. Strategy PnL is meaningless if the *broker* accounting is sloppy. The core requirement is **accounting the operator can trust**: every wallet movement is a ledger entry, every entry is immutable, and wallet state is derivable from the ledger at any time.

## 3. Target users

| User | Who | Needs |
|------|-----|-------|
| **Trading agent** (primary, machine) | The external bot that consumes the REST API | Idempotent order submission, positions/margin state, bulk mark-price push, funding settlement, deterministic error semantics |
| **Operator** (secondary, human) | The developer who runs the service and iterates on the agent | Ledger/positions/performance endpoints, account reset, Docker/Kamal deploy, reconcilable state |

**Trust assumption (current):** single operator, single tenant. The agent is *trusted* for market data (it pushes prices); there is no per-client authentication yet (audit finding M2 — see `tasks.md`). Any change to that assumption is a roadmap decision, not a bug fix.

## 4. Core MVP features (current state)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | Order submission (market/limit/stop kinds, agent-supplied `execution_price` or `ltp`), idempotent via `client_order_id` | ✅ Shipped | Two-layer idempotency: pre-check + unique-index rescue-replay |
| 2 | Margin wallet: balance, `locked_margin`, all movements under `SELECT … FOR UPDATE` | ✅ Shipped | `Ledger::MarginLedger` |
| 3 | Contract-scoped positions (symbol + instrument + option dims), avg price, side flips | ✅ Shipped | ⚠ Known race M4 (see `tasks.md`) |
| 4 | Bulk mark-price push (Redis-backed `MarkPriceStore`) | ✅ Shipped | ⚠ Input validation gap M3 |
| 5 | Liquidation engine: cache check → `LiquidationJob` → DB re-check → force-close (internal, reduce-only) | ✅ Shipped | ⚠ False-success gap M6 |
| 6 | Funding settlement per position, idempotent by `(position, funding_time)` | ✅ Shipped | Partial unique index dedup |
| 7 | Append-only `LedgerEntry` + boot-time `Ledger::Reconciler` (wallet rebuild, drift correction) | ✅ Shipped | The core trust primitive |
| 8 | Risk gate: margin, max-drawdown, position-limit, VIX validators | ✅ Shipped | ⚠ Fail-open defect M5 |
| 9 | Account, ledger, risk-event, performance read endpoints; dev/test account reset | ✅ Shipped | ⚠ `GET /positions/:id` broken (M7) |
| 10 | Indian F&O charges model (STT/GST/SEBI/stamp via `BrokerageCalculator`) | ✅ Shipped | Rates env-tunable |

## 5. Non-goals (MVP and near-term)

- **Real money / real order routing.** Nothing here touches a live exchange's order path. Exchange client gems (DhanHQ, coindcx) are for instrument *catalogs* only.
- **Multi-tenant auth.** No per-account API keys, no login. Single-operator trust model (see §3). Auth is a roadmap item, deliberately minimal.
- **Browser UI / dashboard.** API-only. (A visual language exists in `design.md` §5 for *if* one is ever added.)
- **Own order book / market making.** The agent supplies prices; the internal `OrderBook` is a per-request snapshot used for slippage/latency simulation, not a real matching venue.
- **Strategy layer as a product.** `app/services/strategy/*` and several `market_data/*` services exist but have **no runtime callers** (audit S7). Treat them as unwired scaffolding until a decision is made — do not build features on them.
- **Real-time streaming.** No WebSockets. The push model (agent POSTs prices/funding) is the contract.

## 6. Success criteria (how we know the broker is trustworthy)

1. **Ledger invariant:** `wallet balance == Σ ledger entries` — the Reconciler runs at every boot and reports zero drift.
2. **Idempotency invariant:** replaying the same `client_order_id` never creates a second order, fill, or ledger entry.
3. **Money precision invariant:** all money is `BigDecimal` end-to-end over `decimal(36,18)` columns; no Float arithmetic on stored values.
4. **Liquidation correctness:** every `POSITION_LIQUIDATED` risk event corresponds to a position that actually closed (currently violated — M6).
5. **The TypeScript smoke suite** (`smoke-test.ts`) invariants table passes against a Docker deployment.
6. All seven MUST findings from the 2026-09-25 audit (`REVIEW.md`) are closed — tracked in `tasks.md`.

## 7. Release criteria for "audit-clean" v1

The audit (`REVIEW.md`) defines the exit bar: M1–M7 closed with regression specs, S-tier burn-down ≥ 80%, CI includes brakeman + bundler-audit + secret scanning (added by M1's fix).
