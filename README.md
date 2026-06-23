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

# Copy environment file
cp .env.example .env

# Configure database
# Edit config/database.yml for your PostgreSQL credentials

# Run migrations
rails db:migrate

# Start Redis (if running locally)
redis-server

# Start the API
bin/rails server
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `REDIS_URL` | Redis connection URL (default `redis://localhost:6379/0`) |
| `PAPER_EXCHANGE_MAX_DRAWDOWN` | Max portfolio drawdown before rejection (default `0.20`) |
| `PAPER_EXCHANGE_MAX_POSITIONS` | Max open positions per account (default `10`) |
| `PAPER_EXCHANGE_MAX_POSITION_VALUE` | Max position value before margin rejection (default `500000`) |
| `DHAN_CLIENT_ID` | DhanHQ client ID (required for data APIs) |
| `DHAN_ACCESS_TOKEN` | DhanHQ access token |

---

## API Reference

### Orders
```
POST   /api/orders
GET    /api/orders
GET    /api/orders/:id
DELETE /api/orders/:id
```

Create order payload:
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

### Positions
```
GET /api/positions
GET /api/positions/:id
```

### Ledger
```
GET /api/ledger
```

### Performance
```
GET /api/performance
```

### Risk Events
```
GET /api/risk_events
```

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

---

## Status

| Area | Status |
|------|--------|
| Exchange simulator core | Production-grade |
| Dhan instrument catalog | Integrated via DhanHQ gem |
| Binance USD-M catalog | Integrated via public API |
| CoinDCX futures catalog | Integrated via coindcx-client gem |
| Risk & brokerage engine | Done |
| REST API | Done |
| Backtesting runner | Next |
| Live broker adapters | Next |
| Market feed consumer | Next |

---

## Contributing

1. Follow Rails conventions: domain logic goes in `app/services`, state in `app/models`.
2. Keep the exchange-first contract intact: strategies must not depend on a specific broker.
3. Run `ruby -c` or specs before submitting changes.
4. Do not commit secrets or `.env` files.

---

## License

Proprietary — AlgoScalperAPI.
