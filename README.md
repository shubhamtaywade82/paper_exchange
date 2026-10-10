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
- Docker + Docker Compose (for the 3-process deployment topology)

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

See `.env.example` for the complete list with defaults and one-line descriptions. Key variables:

| Variable | Purpose |
|----------|---------|
| `PAPER_EXCHANGE_API_KEY` | Shared operator API key required by every `/api` request via the `X-API-Key` header. No default; production refuses to boot without it |
| `REDIS_URL` | Redis connection URL (default `redis://localhost:6379/0`) |
| `DATABASE_URL` | PostgreSQL connection URL |
| `PAPER_EXCHANGE_MARGIN` | Default paper margin for new/reset accounts (default `10000`) |
| `PAPER_EXCHANGE_MAX_DRAWDOWN` | Max drawdown from the equity **high-water mark** before rejection (default `0.20`). P1-1: compares against the persisted peak, not initial margin |
| `PAPER_EXCHANGE_MAX_POSITIONS` | Max open positions per account (default `10`) |
| `PAPER_EXCHANGE_MAX_POSITION_VALUE` | Max position notional (default `500000`). P1-2: uses the same reference price for the risk gate and the margin lock |
| `PAPER_EXCHANGE_MAINTENANCE_MARGIN_RATE` | Maintenance margin rate for liquidation prices (default `0.004`) |
| `PAPER_EXCHANGE_ORDER_TTL_MINUTES` | Open orders older than this are expired by the recurring sweep (default `60`) |
| `PAPER_EXCHANGE_STT_OPTIONS_SELL` | NSE STT on options sell-side (default `0.15` = 0.15%, P1-3; was 0.05%) |
| `PAPER_EXCHANGE_STT_FUTURES_SELL` | NSE STT on futures sell-side (default `0.05` = 0.05%, P1-3; was 0.01%) |
| `PAPER_EXCHANGE_MARK_PRICE_CACHE_TTL` | TTL in seconds for the in-process mark price cache (default `2`, P2-3) |
| `PAPER_EXCHANGE_FORCE_SSL` | Force HTTPS in production (default `true`, hardening NEW-3) |
| `PAPER_EXCHANGE_ALLOWED_HOSTS` | Comma-separated allowed hostnames for DNS-rebinding protection (default permissive, hardening NEW-4) |
| `PAPER_EXCHANGE_ENABLE_BINANCE` | Enable the Binance USD-M provider adapter for autonomous market data (default `false`) |
| `PAPER_EXCHANGE_ENABLE_COINDCX` | Enable the CoinDCX futures provider adapter (default `false`) |
| `DHAN_CLIENT_ID` / `DHAN_ACCESS_TOKEN` | DhanHQ credentials (required for Indian instrument catalogs) |

### Market data: two modes

PaperExchange supports **two market-data modes**:

**1. Autonomous mode (provider adapters, target architecture):**
Enable `PAPER_EXCHANGE_ENABLE_BINANCE=true` and/or `PAPER_EXCHANGE_ENABLE_COINDCX=true`,
then start the `market_data` process (`bin/market_data` or `docker compose --profile market_data up`).
The `ConnectionSupervisor` maintains WebSocket connections to the venue's public
feed, normalizes events into the venue-aware `QuoteStore` + the Redis tick stream,
and drives autonomous matching, protection monitoring, and liquidation. The
trading bot is **optional** in this mode — open orders, stop-losses, take-profits,
and liquidations continue to function when the bot is offline.

**2. Agent-driven mode (legacy, default):**
When no provider adapter is enabled, the broker does **not** open its own
connection to any exchange. The trading agent pushes market data:
- `execution_price` on `POST /api/orders` pins the fill price.
- `POST /api/mark_prices` drives `Risk::LiquidationEngine`.
- `POST /api/market_events` feeds the tick stream for strategy context.
- `POST /api/funding_events` settles perpetual funding.

Known blind window (agent-driven mode): a leveraged position opened *after*
the last mark-price push for its symbol is unmonitored until the next push
for that symbol arrives. Autonomous mode eliminates this gap — the
provider adapter pushes continuously.

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

### Exchange Status
```
GET /api/exchange/status
```
Returns provider connectivity, quote freshness, and matching worker
liveness. 200 when all providers are connected and no quotes are stale;
503 when degraded. Useful for load balancers and operators to detect when
the exchange's own market-data feeds are down before stale quotes cause
bad fills.

### Position Protections
```
POST   /api/positions/:position_id/protections
GET    /api/positions/:position_id/protections
DELETE /api/positions/:position_id/protections/:id
```
Attach durable stop-loss, take-profit, or trailing-stop policies to an open
position. These survive process restarts — the `ProtectionMonitorJob`
(every 3 seconds) checks each active protection against the latest mark
price and triggers a force-close order when the breach condition is met.
Supports OCO (one-cancels-other) via a shared `oco_group_id`.

```json
{
  "protection": {
    "protection_type": "stop_loss",
    "trigger_price": 54000,
    "quantity": 0.1
  }
}
```

---

## Project Structure

```
app/
  controllers/
    api/                      # REST endpoints (orders, positions, protections, exchange status, ...)
  models/
    paper_exchange/           # persisted trading entities (orders, positions, trades)
    position_protection.rb   # durable SL/TP/trailing-stop/OCO policies
    account.rb · ledger_entry.rb · risk_event.rb · funding_payment.rb
  services/
    exchange/                 # core trading workflow (PaperExchange, MatchingWorker, engines)
    risk/                     # validators + liquidation engine (incl. CurrencyValidator)
    ledger/                   # immutable event logging + reconciler
    market_data/              # QuoteStore, TickProcessor, MarkPriceStore, ConnectionSupervisor
      providers/              # BinanceUsdm, CoindcxFutures adapters
    projections/              # derived read models (PnL, portfolio, performance)
    strategy/                 # signal generation and orchestration
  jobs/
    liquidation_job.rb · funding_job.rb · expire_orders_job.rb
    matching_worker_job.rb    # autonomous matching (every 2s)
    protection_monitor_job.rb # autonomous SL/TP monitoring (every 3s)
    option_expiry_job.rb      # daily option expiry settlement
config/
  routes.rb                   # /api and /api/v1; positions have nested protections
db/
  migrate/                    # schema migrations (incl. venue, max_equity_achieved, position_protections)
bin/
  market_data                 # standalone market-data supervisor entrypoint
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

| Area | Status |
|------|--------|
| Exchange simulator core | Production-grade |
| Non-crypto wallet/equity accounting (P0-1: full-notional margin lock, realized PnL per fill) | Done |
| Funding settlement atomicity (P0-2: payment + ledger in one transaction; 1x leverage eligible) | Done |
| Max-drawdown gate from equity high-water mark (P1-1: live equity, persisted HWM) | Done |
| Notional-value limit using one authoritative reference price (P1-2) | Done |
| NSE FY2026-27 STT schedule (P1-3: 0.15% options, 0.05% futures) | Done |
| Performance metrics from REALIZED_PNL ledger stream (P1-4) | Done |
| Cancellation atomicity — lock + state + margin release in one transaction (P1-5) | Done |
| Currency consistency gate (P1-6: INR/USD/USDT isolation) | Done |
| Limit order price improvement + stop-market semantics (P2-1) | Done |
| Wallet.locked includes position + order margin (P2-2) | Done |
| MarkPriceStore local cache TTL (P2-3: 2s, prevents stale cross-process reads) | Done |
| Dhan instrument catalog | Integrated via DhanHQ gem |
| Binance USD-M catalog + provider adapter | Integrated (`PAPER_EXCHANGE_ENABLE_BINANCE`) |
| CoinDCX futures catalog + provider adapter | Integrated (`PAPER_EXCHANGE_ENABLE_COINDCX`) |
| Venue-aware QuoteStore (bid/ask/mark/funding per venue+instrument) | Done |
| Venue identity on orders and positions | Done |
| Autonomous matching worker (event-driven, fills open orders from live quotes) | Done |
| Durable position protections (SL/TP/trailing/OCO, survives restarts) | Done |
| Option expiry settlement (daily cash settlement) | Done |
| 3-process deployment topology (web / jobs / market_data) | Done |
| Deep health check (`GET /health`: Postgres + Redis + Solid Queue) | Done |
| Global JSON error envelope on all API endpoints | Done |
| Non-root production container | Done |
| SSL + DNS-rebinding protection in production | Done |
| Redis in CI (exercises the real Redis path, not degraded mode) | Done |
| Margin wallet (available/locked balance, atomic lock/unlock) | Done |
| Leverage, margin type, liquidation price on positions | Done |
| Liquidation engine (in-memory checks, async force-close) | Done |
| Perpetual funding settlement | Done |
| Order idempotency (`client_order_id`) | Done |
| Ledger reconciliation on boot (fatal in production) | Done |
| Ledger immutability (readonly guard + UPDATE-blocking trigger) | Done |
| Keyset pagination on list endpoints | Done |
| REST API (authenticated via `X-API-Key`) | Done |
| Market event ingestion (`POST/GET /api/market_events`) | Done |
| Market-structure snapshots (`POST/GET /api/market_structure`) | Done |
| Strategy signals (`POST /api/strategy/signals`) | Done |
| Indicator engine compute / candle builder / greeks / option chain | Roadmap — not wired |
| Backtesting runner | Next |
| Live broker adapters (order routing) | Next |

---

## Contributing

1. Follow Rails conventions: domain logic goes in `app/services`, state in `app/models`.
2. Keep the exchange-first contract intact: strategies must not depend on a specific broker.
3. Run `ruby -c` or specs before submitting changes.
4. Do not commit secrets or `.env` files.

---

## License

Proprietary — AlgoScalperAPI.
