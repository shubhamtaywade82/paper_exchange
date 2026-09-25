# Design — Design System & UI Guidelines for paper_exchange

> **Primary reader:** AI developer. Last updated: 2026-09-25.
> **Scope note:** paper_exchange is **API-only** — there is no browser UI today. The real "design surface" is the **HTTP/JSON interface** the trading agent consumes, so this file defines (§1–§4) the API design language: response shapes, error semantics, status codes, naming vocabulary. §5 defines the visual language **if** a monitoring dashboard is ever added, so it doesn't get invented ad-hoc later.
> Companion files: `design` cross-references `rules.md` (backend constraints) and `architecture.md` (module map).

---

## 1. Design philosophy (API surface)

**Boring, predictable, agent-friendly JSON.** The consumer is a machine that must parse every response without guessing:

1. **Flat objects, snake_case keys** — no envelope wrappers like `{ data: { … } }` except where already established (lists are bare JSON arrays).
2. **One error shape, everywhere:** `{ "error": "<human-readable, actionable message>" }` — single key, no nesting, no error codes yet (add codes only via a `tasks.md` decision, since the agent parses messages).
3. **Decimals are numbers, parsed as decimal.** Money fields carry full `decimal(36,18)` precision. Agents MUST NOT parse them as float64 — documented in README's smoke-test contract. (If we ever switch to strings, that's a versioned API change, not a silent edit.)
4. **Timestamps are ISO 8601 with zone** (Rails default serialization of `placed_at`, `occurred_at`, `updated_at`).
5. **Both path styles work** for legacy reasons: `/api/mark_prices` and `/api/mark-prices` (same for funding). New endpoints: **snake_case only**, mounted under `/api` and `/api/v1` (the router mirrors both — keep it that way).

## 2. Endpoint catalog (current contract)

| Method | Path | Purpose | Notes |
|--------|------|---------|-------|
| GET | `/api/account` | Wallet + equity snapshot | balance, locked, equity, PnL |
| POST | `/api/account/reset` | Wipe & re-seed account | dev/test only (⚠ no wrapping transaction — S11) |
| GET | `/api/orders` | Recent orders | cap 200, newest first |
| POST | `/api/orders` | Submit order | 201 + order JSON; idempotent on `client_order_id` |
| GET | `/api/orders/:id` | Order detail | |
| DELETE | `/api/orders/:id` | Cancel + release locked margin | ⚠ unguarded transition (S1) |
| GET | `/api/positions` | Projected open positions | |
| GET | `/api/positions/:id` | Position detail | ⚠ **broken, always 404 (M7)** — do not consume until fixed |
| GET | `/api/risk_events` | Risk audit trail | cap 200 |
| GET | `/api/performance` | Portfolio metrics | ⚠ `profit_factor` may be `Infinity` (S14) |
| GET | `/api/ledger` | Ledger entries | cap 500 |
| POST | `/api/mark_prices` | Bulk mark-price push | `{ prices: { SYMBOL: price } }`; ⚠ unvalidated (M3) |
| POST | `/api/funding_events` | Funding settlement | ⚠ rate/time unvalidated (M3) |
| GET | `/up` | Health check | Rails default |

**Account selection (until auth lands, M2/T1.2):** header `X-Account-Id` (or `X-API-Key`, or `params[:account_id]`), defaulting to `"default"`. Treat the account id as case-sensitive string.

## 3. Status codes & error semantics (fixed contract — see `rules.md` §3)

| Status | Meaning | Triggered by |
|--------|---------|--------------|
| 200 / 201 | OK / created | reads, successful order submit |
| 400 | Malformed input | `ArgumentError` |
| 402 | Insufficient margin | `Ledger::InsufficientMarginError` |
| 404 | Resource not found (or wrong account) | missing id — **no existence oracle across accounts** |
| 422 | Validation failure (processable content) | `OrderValidationError` (dry-validation) |
| 500 | Internal error | logged server-side, body is always `{ "error": "Internal error" }` — never leak stack traces |

Error message style: one sentence, actionable, includes the offending field where cheap — e.g. `"quantity must be positive"`, not `"Invalid order"`. `PositionGoneError` messages explain the race (`"…no open position on the opposite side to reduce (position gone)"`) — keep that pattern.

## 4. Domain vocabulary (canonical values — do not fork)

- **`order_kind`:** `market` · `limit` · `stop` (historically `order_type`; controller accepts both, emits `order_type` in JSON).
- **`status` (order):** `pending → open → filled | partially_filled | cancelled | expired | rejected`. Transitions must be guarded (S1); `expired` currently unreachable (S2).
- **`side`:** `buy` · `sell` (downcased at ingress). Position `side`: `long`/`short` derived from quantity sign.
- **`instrument_type`:** UPPERCASE — `EQUITY`, `CRYPTO_PERPETUAL`, `FUTURE`, `OPTION` (+ catalog variants). Default when absent: `CRYPTO_PERPETUAL`.
- **`RiskEvent.event_type`:** `POSITION_LIQUIDATED`, `LIQUIDATION_FAILED`, `*_REJECTED` (suffix is machine-checked by `submit_order`), `RISK_EVALUATION_ERROR`.
- **`LedgerEntry.event_type`:** UPPERCASE event names (`MARGIN_LOCKED`, `FUNDING_FEE`, `REALIZED_PNL`, `ADJUSTMENT`, …) — ⚠ legacy `"trade"` is lowercase (N2); write no new lowercase values.
- **Instrument identity (contract scope):** `(symbol, instrument_type, option_type, strike_price, expiry_date)` — the 5-tuple that identifies a position. NULL option dims for non-options.

**List-cap policy:** every list endpoint has a hard cap (200/500/200). Responses do not advertise truncation today (N6 tracks cursor pagination). Until then: consumers must not assume completeness; a `tasks.md` decision will add pagination metadata.

## 5. Future dashboard visual language (only if a UI is added)

Apply **only when building a monitoring/dashboard surface**. Rationale: this is a trading-domain tool; the reference class is Bloomberg/TradingView-style dense terminals, not marketing sites.

### 5.1 Color palette

| Token | Value | Use |
|-------|-------|-----|
| `bg/base` | `#0E1116` | App background |
| `bg/surface` | `#161B22` | Cards, tables |
| `bg/raised` | `#1F2630` | Hover, inputs |
| `text/primary` | `#E6EDF3` | Default text |
| `text/muted` | `#8B949E` | Labels, axis, captions |
| `accent/profit` | `#2EA043` | Positive PnL, long, fills-buy |
| `accent/loss` | `#F85149` | Negative PnL, short, liquidations |
| `accent/info` | `#58A6FF` | Links, selection, focus |
| `accent/warn` | `#D29922` | Drawdown warnings, stale prices, risk events |
| `border` | `#30363D` | Hairlines, table grid |

Rules: color encodes **meaning only** (profit/loss/warn/info) — never decoration. Both accent colors must pass WCAG AA on `bg/surface`. Never use red/green alone to carry meaning (pair with sign `+/−` and arrows ▲▼).

### 5.2 Typography

- **Numbers (all money/qty/prices):** monospace with tabular figures — `JetBrains Mono` or `IBM Plex Mono`, fallback `ui-monospace`. Right-aligned in tables. This is non-negotiable for ledger alignment.
- **UI text/labels:** system sans (`Inter` / `-apple-system` / `Segoe UI`).
- Scale: 12px table text · 13px body · 16px section titles · 28px page H1; line-height 1.5 body, 1.2 headings.

### 5.3 Spacing & layout

- 4/8px spacing grid (`4, 8, 12, 16, 24, 32, 48`).
- Data-table rows 40px; compact ledger rows 32px.
- Max content width 1440px; sidebar nav 240px; 12-col grid, 16px gutters.
- Density-first: padding is a scarce resource — prefer one more visible row over air.

### 5.4 Component patterns

- **Data table:** sticky header, right-aligned mono numerals, `accent/profit`/`accent/loss` signed values, row hover `bg/raised`, empty state "No entries" (never a blank frame).
- **Stat card row:** label (`text/muted`, 12px, uppercase) over value (mono, 20px) + delta chip (▲/▼ + %); used for Balance / Locked / Equity / Realized PnL.
- **Event feed (risk events):** left color rail by severity (`loss` = LIQUIDATION_FAILED, `warn` = *_REJECTED, `info` = informational), mono timestamp, one-line detail.
- **Price chart:** `accent/info` line, crosshair with mono tooltip, last-price pill anchored right.
- **No modals for read-only data** — expandable rows / side panels. Destructive actions (account reset) get a typed confirmation modal.

### 5.5 Visual style summary

Dark, dense, terminal-adjacent, data-honest: no illustration, no gradients on data surfaces, no rounded corners beyond 6px, motion limited to 150ms fades (numbers must never animate/tween — values change discretely). Empty/error states are explicit text, never skeleton-shimmer beyond initial load.
