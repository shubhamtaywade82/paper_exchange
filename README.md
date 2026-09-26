# PaperExchange

**Production-grade exchange simulator and paper trading engine for AlgoScalperAPI.**
Supports Indian equity, F&O (via DhanHQ), and crypto futures (Binance USD-M, CoinDCX) through a unified REST API and deterministic strategy layer.

---

## Overview

PaperExchange is a Rails 8 API application that simulates exchange behavior — order validation, matching, risk gating, brokerage/charge calculation, position management, and immutable ledgering — without touching a live broker or exchange.

It is designed as an **exchange-first** system: strategies call `PaperExchange.submit_order`, and a broker adapter layer can later route the same order flow to live venues (Dhan, Binance, CoinDCX) with minimal changes to strategy code.

---

## Key Features

- **Multi-market instrument catalogs**
  - DhanHQ: equity, F&O (FUTIDX/OPTIDX/FUTSTK/OPTSTK), currency, commodity via public segmentwise API and scrip master CSV
  - Binance USD-M: perpetual futures via `fapi/v1/exchangeInfo`
  - CoinDCX: futures via `coindcx-client` gem public endpoints
- **Exchange-first order execution**
  - `PaperExchange.submit_order` is the single entrypoint for all order flow
- **Pluggable risk validation**
  - Derivative-only enforcement for index underlyings (NIFTY, BANKNIFTY, SENSEX, etc.)
  - VIX gate, margin validator, position limit validator, max drawdown validator
- **Realistic charges**
  - Indian market STT, GST, SEBI fees, stamp duty, exchange transaction charges
  - Configurable per instrument type
- **Unified event model**
  - `MarketEvent`, `OrderEvent`, `TradeEvent` — source-agnostic across CSV, Parquet, TimescaleDB, live feeds, and Redis Streams
- **Immutable ledger & projections**
  - Ledger entries and risk events are append-only
  - Positions and PnL are derived at query time via projection services
- **REST API**
  - Orders, positions, ledger, performance metrics, risk events
- **Strategy layer**
  - `IndicatorEngine`, `MarketStructureEngine`, `StrategyEngine`, `OptionSelector`, `Signal` value object
- **Test-friendly**
  - RSpec, FactoryBot, Faker, WebMock, VCR

---

## Architecture

- **Models (`app/models`)** — persisted entities only. No business logic.
- **Services (`app/services`)** — all domain logic and workflows.
  - `exchange/` — matching, fill, slippage, brokerage, position management, order validation, instrument catalogs
  - `risk/` — risk manager and validators
  - `ledger/` — immutable order/trade logging
  - `market_data/` — tick processing, candle building, greeks, option chain caching
  - `projections/` — position and portfolio read models
  - `strategy/` — indicator, market structure, strategy orchestration, option selection
- **Controllers (`app/controllers/api`)** — thin REST layer
- **Migrations (`db/migrate`)** — schema-only changes; seeded data via instrument catalog services

### Design rules
- If deleting the database table renders the object meaningless, it lives in `app/models`.
- Stateless workflows, calculations, and orchestration live in `app/services`.
- Index cash trading is permanently prohibited; all index orders must route through F&O derivatives.

---

## Supported Markets

| Market | Instruments | Catalog Source | Status |
|--------|-------------|----------------|--------|
| NSE / BSE Equity | EQUITY | DhanHQ gem | Paper + Live-ready |
| NSE / BSE F&O | FUTIDX, OPTIDX, FUTSTK, OPTSTK | DhanHQ gem | Paper + Live-ready |
| NSE / BSE Currency | FUTCUR, OPTCUR | DhanHQ gem | Paper |
| MCX Commodity | FUTCOM, OPTFUT | DhanHQ gem | Paper |
| Binance USD-M Futures | Perpetual contracts | `fapi.binance.com` | Paper |
| CoinDCX Futures | Perpetual contracts | `coindcx-client` gem | Paper |

---

## Getting Started

### Prerequisites

- Ruby 3.2+
- Rails 8.1+
- PostgreSQL
- Redis (for market data pipeline and background jobs)
- Bundler

### Installation

```bash
# Clone and install dependencies
git clone <repository-url>
cd paper_exchange
bundle install

# Copy environment file (required before docker compose)
cp .env.example .env
# Edit .env: regenerate RAILS_MASTER_KEY and SECRET_KEY_BASE with:
#   openssl rand -hex 16
#   openssl rand -hex 64

# Configure database
# Edit config/database.yml for your PostgreSQL credentials

# Run migrations
rails db:migrate

# Start Redis (if running locally)
redis-server

# Start the API
bin/rails server
```

### Authentication

Every request under `/api` must present the operator's shared API key:

```bash
curl -H "X-API-Key: $PAPER_EXCHANGE_API_KEY" -H "X-Account-Id: my-account" \
  http://localhost:3100/api/account
```

**Trust model (audit M2):** single-operator deployment. The `X-API-Key`
header authenticates the request (constant-time compare against
`PAPER_EXCHANGE_API_KEY`); `X-Account-Id` then selects which paper account
the authenticated operator acts on — it is identity, not authorization.
Requests without a valid key get `401`. **Production refuses to boot** when
`PAPER_EXCHANGE_API_KEY` is unset, so the API can never be silently deployed
unauthenticated. Per-account API keys are a roadmap item (see `prd.md`
non-goals). CORS is restricted to loopback origins for local browser tools;
non-browser clients are unaffected by CORS.

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `PAPER_EXCHANGE_API_KEY` | Shared operator API key required by every `/api` request via the `X-API-Key` header (audit M2). No default — production refuses to boot without it |
| `REDIS_URL` | Redis connection URL (default `redis://localhost:6379/0`) |
| `PAPER_EXCHANGE_MARGIN` | Default paper margin for new/reset accounts (default `10000`) |
| `PAPER_EXCHANGE_MAX_DRAWDOWN` | Max portfolio drawdown before rejection (default `0.20`) |
| `PAPER_EXCHANGE_MAX_POSITIONS` | Max open positions per account (default `10`) |
| `PAPER_EXCHANGE_MAX_POSITION_VALUE` | Max position value before margin rejection (default `500000`) |
| `PAPER_EXCHANGE_MAINTENANCE_MARGIN_RATE` | Maintenance margin rate used to derive liquidation prices for leveraged futures positions (default `0.004`) |
| `PAPER_EXCHANGE_ORDER_TTL_MINUTES` | Open orders older than this are expired by the recurring sweep, releasing their locked margin (default `60`) |
| `DHAN_CLIENT_ID` | DhanHQ client ID (required for data APIs) |
| `DHAN_ACCESS_TOKEN` | DhanHQ access token |

### Crypto market data ownership

This broker does **not** open its own connection to Binance (or any exchange)
for live prices. All market data ownership lives in the trading agent that
drives it — the agent already needs the live feed for its own strategy, and
keeping it out of the broker means the broker stays a simple, deterministic,
restart-safe request/response server with no WebSocket reconnection logic to
babysit.

The agent feeds the broker two things:

1. **`execution_price`** on `POST /api/orders` — pins the exact fill price
   for the order (no slippage is applied when it is given; orders without
   it fill through the deterministic slippage model off the order-book
   snapshot). Required in practice for crypto symbols, since the broker has
   no other price source for them.
2. **`POST /api/mark_prices`** — a periodic bulk push of `{symbol: price}`
   for every open position's symbol. This is what drives
   `Risk::LiquidationEngine` — a leveraged position's liquidation price is
   only checked when a price for its symbol arrives here, so push at least
   as often as you need liquidation to react (every few seconds for
   anything highly leveraged). Known blind window (audit N9, by design and
   bounded by your push cadence): a leveraged position opened *after* the
   last push for its symbol is unmonitored until the next push for that
   symbol arrives.

Tick-level history (as opposed to the latest mark price) has its own
channel: push what your feed sees to `POST /api/market_events` and read it
back with `GET /api/market_events` (capped Redis stream — see the API
reference). Use mark prices for liquidation/wallet math, market events for
strategy context and analysis.

Perpetual futures funding is likewise agent-driven: call
`POST /api/funding_events` when your feed reports a funding settlement, and
the broker posts the funding fee against every open leveraged position on
that symbol (see `FundingJob`).

---

## API Reference

### Orders
```
POST   /api/orders
GET    /api/orders
GET    /api/orders/:id
DELETE /api/orders/:id
```

Create order payload (Indian F&O):
```json
{
  "account_id": "ACC-001",
  "symbol": "NIFTY",
  "side": "buy",
  "quantity": 50,
  "order_type": "market",
  "instrument_type": "OPTIDX",
  "option_type": "CE",
  "strike_price": 26000,
  "expiry_date": "2024-06-27",
  "exchange_segment": "NSE_FNO"
}
```

Create order payload (crypto perpetual futures — `client_order_id` and
`execution_price` are how the agent drives idempotency and pricing; see
"Crypto market data ownership" above):
```json
{
  "account_id": "ACC-001",
  "symbol": "BTCUSDT",
  "side": "buy",
  "quantity": 0.01,
  "order_type": "market",
  "instrument_type": "CRYPTO_PERPETUAL",
  "leverage": 10,
  "margin_type": "cross",
  "execution_price": 65123.45,
  "client_order_id": "agent-uuid-123"
}
```

### Account
```
GET /api/account
```
Wallet split (`available_balance`/`locked_margin`) plus live equity — sync
from this on startup and after any gap in connectivity rather than
computing balance/margin locally.

### Positions
```
GET /api/positions
GET /api/positions/:id
```

### Ledger
```
GET /api/ledger
```
Append-only cash-flow history (SCREAMING_SNAKE_CASE `event_type`s: TRADE,
MARGIN_LOCKED, MARGIN_UNLOCKED, FEE, REALIZED_PNL, FUNDING_FEE, ADJUSTMENT).
Rows are immutable once written — app-level `readonly?` guard plus a Postgres
trigger that blocks UPDATE outright; the only deleter is the explicit account
reset. Corrections are posted as new compensating entries (the boot Reconciler
derives wallet state from this stream, so history must never change).

### Performance
```
GET /api/performance
```

### Risk Events
```
GET /api/risk_events
```

### List-endpoint pagination
`GET /api/orders`, `GET /api/ledger` and `GET /api/risk_events` are keyset
paginated (audit N6) — the old hard caps (200/500/200) silently truncated
history. Response envelope:
```json
{ "data": [ ... ], "next_cursor": "<opaque>" }
```
`next_cursor` is null on the last page; pass it back as `?cursor=` to walk
older items. `?limit=` is clamped to 1–500 (default 100). Tampered cursors
are a 400, not a 500.

### Mark Prices (crypto)
```
POST /api/mark_prices
```
```json
{ "prices": { "BTCUSDT": "65123.45", "ETHUSDT": "3200.10" } }
```

### Funding Events (crypto)
```
POST /api/funding_events
```
```json
{ "symbol": "BTCUSDT", "funding_rate": "0.0001", "mark_price": "65123.45" }
```

### Market Events (tick stream)
```
POST /api/market_events          # single tick or { "events": [ ... ] } batch (max 500)
GET  /api/market_events?symbol=BTCUSDT&count=50&before=<cursor>
```
Push ticks from your feed here; they land in the capped Redis stream
(`paper_exchange:market:ticks`, ~100k entries) that strategy context and
future candle building read. `price`/`ltp`/`bid`/`ask` (at least one
required) must be finite and > 0; a malformed tick rejects the whole request
422 with nothing enqueued. `GET` reads back newest-first with a stream
cursor; 503 means the tick stream (Redis) is unavailable and ticks were NOT
accepted.

### Market Structure (SMC context)
```
POST /api/market_structure       # append a snapshot per symbol+timeframe
GET  /api/market_structure?symbol=BTCUSDT&timeframe=5m
GET  /api/market_structure?timeframe=5m      # latest per symbol
```
```json
{ "symbol": "BTCUSDT", "timeframe": "5m", "trend": "bullish", "bos": true,
  "choch": false, "bullish_fvg_count": 2, "bearish_fvg_count": 1,
  "liquidity_sweep": "sell_side", "order_block": "bullish_ob",
  "premium_discount": "premium", "as_of": "2026-09-26T10:00:00Z" }
```
Snapshots are append-only rows; reads always take the newest per
(symbol, timeframe). `trend` is one of bullish|bearish|range|neutral.

### Strategy Signals (pre-trade assessment)
```
POST /api/strategy/signals
```
```json
{ "signal": { "symbol": "RELIANCE", "side": "buy", "quantity": 2,
              "instrument_type": "EQUITY", "ltp": 2500.0, "leverage": 1,
              "context": { "vix": 14.2 } },
  "timeframe": "5m" }
```
Read-only pre-flight through the SAME risk gate `POST /api/orders` runs —
no order is created, nothing is locked. Returns `decision: allow|reject`,
the per-check outcomes, `rejections` (the `*_REJECTED` vocabulary
`/api/risk_events` uses), and the symbol's latest market-structure snapshot
for context. Submit the trade itself via `POST /api/orders`.

---

## Project Structure

```
app/
  controllers/
    api/                      # REST endpoints
  models/
    paper_exchange/           # persisted entities (orders, positions, ledger, snapshots)
  services/
    exchange/                 # core trading workflow
    risk/                     # validators and risk manager
    ledger/                   # immutable event logging
    market_data/              # feed, candles, greeks, option chain
    projections/              # derived read models (PnL, portfolio)
    strategy/                 # signal generation and orchestration
config/
  routes.rb                   # conventional Rails API namespace
db/
  migrate/                    # schema migrations
```

---

## Testing

```bash
# Lint / syntax check
bin/rubocop

# Run specs
bundle exec rspec
```

### Crypto Engine Smoke Test (End-to-End Accounting Invariants)

A TypeScript integration suite verifying core perpetual accounting invariants against the live containerized broker (initial margin deduction, flat 0.04% taker fees, weighted-average entry prices, partial realization, funding rate settlements, and immutable ledger cash reconciliation):

```bash
# 0. One-time: copy .env.example to .env (regenerate the secrets inside it)
cp .env.example .env
# Edit .env and replace RAILS_MASTER_KEY + SECRET_KEY_BASE with fresh values:
#   openssl rand -hex 16   # RAILS_MASTER_KEY
#   openssl rand -hex 64   # SECRET_KEY_BASE

# 1. Start Docker services (PostgreSQL, Redis, and the Rails dev server)
docker compose up -d --build

# 2. Reset or initialize test account (test-account-1)
docker compose exec api bin/rails runner "
  account_id = 'test-account-1'
  order_ids = PaperExchange::PaperOrder.where(account_id: account_id).pluck(:id)
  FundingPayment.where(account_id: account_id).delete_all
  PaperExchange::PaperTrade.where(paper_order_id: order_ids).delete_all
  PaperExchange::PaperPosition.where(account_id: account_id).delete_all
  PaperExchange::PaperOrder.where(account_id: account_id).delete_all
  LedgerEntry.where(account_id: account_id).delete_all
  Account.find_or_initialize_by(account_id: account_id).update!(
    name: 'Smoke Test Account', currency: 'USD', margin: 10000.0,
    available_balance: 10000.0, current_equity: 10000.0,
    realized_pnl: 0.0, unrealized_pnl: 0.0, locked_margin: 0.0
  )
"

# 3. Run broker API smoke test:
docker compose exec api npm run smoke-test
# or from host:
npm run smoke-test

# 4. Run headless trading lifecycle simulation smoke test:
npm run smoke-test:simulation

# 5. Interactive visual simulation dashboard:
# Open directly in browser:
wslview crypto-trading-lifecycle-simulation.html
# Or serve via Python (http://localhost:8080/crypto-trading-lifecycle-simulation.html):
python3 -m http.server 8080
# Features an optional "🔌 Live API" toggle button (default: OFF / in-memory mock) to stream live orders to port 3100.
```

#### Invariants Verified

| Step | Operation | Invariant / Formula | Expected |
|------|-----------|---------------------|----------|
| 1 | Initial State | `available_balance = margin`, `locked_margin = 0` | $\$10,000.00$ |
| 2 | Seed Mark Price | Initialize mark price for `BTCUSDT` | $\$60,000.00$ |
| 3 | Open Position | Buy 0.1 BTC @ 60k (10x). Margin: $\$600.00$, Fee (0.04%): $\$2.40$ | Avail: $\$9,397.60$, Margin: $\$600.00$ |
| 4 | Mark Price Update | Price $\to \$61,000$. $\text{uPnL} = (61000 - 60000) \times 0.1$ | uPnL: $+\$100.00$ |
| 5 | Add to Position | Buy 0.1 BTC @ 62k (10x). Weighted entry: $\$61,000$, Fee: $\$2.48$ | Avg: $\$61,000.00$, Avail: $\$8,775.12$ |
| 6 | Reduce Position | Sell 0.15 BTC @ 63k. Realized: $+\$300$, Fee: $\$3.78$, Released: $\$915$ | Realized: $+\$300.00$, Avail: $\$9,986.34$ |
| 7 | Funding Settlement | $0.01\%$ funding on $0.05 \times 63000$ notional ($\$3,150$). Fee: $\$0.315$ | Avail: $\$9,986.025$ |
| 8 | Cash Invariant | Total Cash = `wallet.available` + `margin_used` = Initial + PnL - Fees | $\$10,291.025$ |

---

## Status

> **Scope honesty (audit S7/T4.1, decided 2026-09-26; wiring shipped
> same day):** the modules marked **Roadmap** exist in `app/services/`
> but have **no runtime callers** — no routes, jobs, or services invoke
> them. They are kept as scaffolding for planned capabilities, not as
> working features; wire or remove them in a future sprint. Decision
> recorded in `memory.md`.

| Area | Status |
|------|--------|
| Exchange simulator core | Production-grade |
| Dhan instrument catalog | Integrated via DhanHQ gem |
| Binance USD-M catalog | Integrated via public API |
| CoinDCX futures catalog | Integrated via coindcx-client gem |
| Risk & brokerage engine | Done |
| Crypto futures precision (decimal quantities/prices) | Done |
| Margin wallet (available/locked balance, atomic lock/unlock) | Done |
| Leverage, margin type, liquidation price on positions | Done |
| Liquidation engine (in-memory checks, async force-close) | Done |
| Perpetual funding settlement (agent-pushed via `POST /api/funding_events`) | Done |
| Mark price hot state (agent-pushed via `POST /api/mark_prices`) | Done |
| Order idempotency (`client_order_id`) | Done |
| Ledger reconciliation on boot | Done |
| Ledger immutability (readonly guard + UPDATE-blocking trigger, audit N3) | Done |
| Keyset pagination on list endpoints (audit N6) | Done |
| REST API (authenticated via `X-API-Key`) | Done |
| Market event ingestion (`POST/GET /api/market_events` → capped Redis tick stream) | Done — wired 2026-09-26 |
| Market-structure snapshots (`POST/GET /api/market_structure`, DB-backed) | Done — wired 2026-09-26 |
| Strategy signals (`POST /api/strategy/signals` — read-only pre-trade risk assessment) | Done — wired 2026-09-26 |
| Indicator engine (`indicator_engine` — SMA-20 from the tick stream) | Roadmap — compute side not wired to a route/job yet |
| Candle building (`candle_builder`) | Roadmap — not wired |
| Greeks & option chain services (`greeks_service`, `option_chain_service`) | Roadmap — not wired |
| Option selector (`option_selector` — queries `option_snapshots`) | Roadmap — no snapshot producer wired yet |
| VIX gate data source (`vix_gate` — the validator runs, but nothing feeds it VIX) | Roadmap — pass `context: {vix: ...}` on orders or signals to activate |
| Backtesting runner | Next |
| Live broker adapters | Next |

---

## Contributing

1. Follow Rails conventions: domain logic goes in `app/services`, state in `app/models`.
2. Keep the exchange-first contract intact: strategies must not depend on a specific broker.
3. Run `ruby -c` or specs before submitting changes.
4. Do not commit secrets or `.env` files.

---

## License

Proprietary — AlgoScalperAPI.
