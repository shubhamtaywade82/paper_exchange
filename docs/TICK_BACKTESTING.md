# Deterministic tick-based backtesting

## Ownership

PaperExchange owns execution, risk, fills, positions, fees, funding settlement and
the ledger. The trading bot owns historical-data acquisition, strategy decisions
and parameter selection. The replay runner coordinates them. Strategy code must
not implement a second wallet or position ledger.

## Pipeline

1. Load immutable historical L2 snapshots and incremental depth updates, plus
   trades, mark-price and funding events.
2. Validate symbol, timestamp, sequence continuity, finite prices and quantities,
   sorted book levels, and crossed-book conditions.
3. Replay in exchange timestamp, exchange sequence, then original input order.
4. Advance an injected simulation clock. Never globally monkey-patch Time.now.
5. Deliver only events at or before the replay cursor to the strategy.
6. Convert strategy decisions into order intents with stable decision IDs.
7. Execute against visible bid/ask depth, producing multiple fill slices or a
   partial fill when depth is insufficient.
8. Persist each fill, charge, position update and ledger entry at simulated time.
9. Process funding events at their historical timestamps.
10. Record account equity and risk state after each event; generate a run report.

## Current foundation in this branch

- ReplayClock: monotonic, explicit simulation time.
- TickReplay: deterministic chronological ordering with sequence tie-breaks.
- HistoricalOrderBook: validated L2 book, bid/ask walking, VWAP, depth
  consumption, partial fills and optional adverse-slippage bound.

These are isolated primitives; they do not yet change the live MatchingWorker
or existing REST order semantics.

## Required next integration work

- Introduce a replay-aware order gateway inside PaperExchange. It must use the
  L2 execution result rather than the existing execution_price shortcut.
- Extend trade persistence to represent multiple fill slices per order and
  cumulative partial-fill state. Current fill records assume a full fill.
- Inject the replay clock into order placement, fills, ledger events, protection
  evaluation and funding. Existing Time.current calls in money paths must not
  leak wall-clock timestamps into replay.
- Disable live MatchingWorker, protection jobs and funding jobs for replay
  accounts. Replay must process these synchronously in event order.
- Add run-scoped account isolation, stable idempotency keys and a run manifest
  containing dataset checksum, strategy revision, config hash, execution-model
  version, venue, symbols, interval and initial capital.
- Add a runner-facing API or in-process adapter and a run-scoped results API.
- Verify replay twice against the same manifest and assert identical fills,
  ledger rows and equity series.

## Market-data limitations

Aggregate trades do not reconstruct executable L2 depth or queue position.
Best-bid/ask-only history models spread but not market impact. Accurate Binance
USD-M replay requires depth snapshots plus incremental depth updates with
exchange update IDs, reconstructed using Binance's snapshot/diff procedure.
Missing update ranges or invalid book states must invalidate the interval;
never synthesize missing liquidity.

Keep last trade, executable bid/ask, mark price and index price as distinct
event fields. Funding is a separate event. For latency simulation, orders become
eligible only at the first market event after their simulated arrival time.

## Execution semantics

A buy consumes asks from best to worst; a sell consumes bids. The execution
price is the VWAP of consumed levels. Repeated orders against one snapshot share
and consume the same available quantities. Insufficient depth yields a partial
fill or unfilled remainder; it never fills the remainder at an invented price.
An optional max slippage threshold caps adverse movement from the top level.
