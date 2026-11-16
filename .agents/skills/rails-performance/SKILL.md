---
name: rails-performance
description: Use when diagnosing, designing, reviewing, or changing Rails performance across Active Record queries, N+1 behavior, caching, request rendering, Puma capacity, connection pools, background jobs, allocations, memory, and production throughput.
---

# Rails Performance Engineering

## Purpose

Treat Rails performance as an evidence-driven systems problem.

The performance chain is:

workload
-> baseline
-> bottleneck evidence
-> hypothesis
-> smallest targeted change
-> functional verification
-> performance re-measurement
-> production observation

The skill complements `ruby-performance`. Use this skill for Rails-specific boundaries and use `ruby-performance` for Ruby runtime, allocation, GC, profiling, and general benchmark methodology.

## Activate when

- a Rails endpoint, job, query, render, boot, or test suite is slow
- Active Record query count, N+1 behavior, object loading, or query plans are involved
- changing eager loading, preloading, batching, pagination, or selected columns for performance
- changing a database index because of a measured query
- introducing or changing Rails fragment/low-level/SQL caching
- investigating cache hit rate, invalidation, stampede, or key construction
- changing Puma workers/threads or `WEB_CONCURRENCY` / `RAILS_MAX_THREADS`
- changing database connection pools or encountering pool exhaustion
- increasing background-job concurrency or batch size
- analyzing request throughput, queueing, memory, or downstream saturation
- adding a Rails performance regression check
- reviewing a Rails performance-sensitive change

Do not activate merely because a loop, association, or query exists. Require a workload, symptom, or explicit measurable target.

## Repository inspection

Before changing Rails performance, inspect:

1. Ruby and Rails versions;
2. Active Record adapter and database version;
3. representative data volume/cardinality;
4. existing query logs and instrumentation;
5. current request/job latency and throughput evidence;
6. existing eager-loading/query conventions;
7. schema indexes and constraints;
8. Puma workers/threads and process limits;
9. Active Job/queue adapter and worker concurrency;
10. database connection-pool configuration;
11. cache store, namespace/versioning, and expiration conventions;
12. existing benchmarks and performance tests;
13. CI performance checks;
14. deployment/container CPU and memory limits when runtime capacity changes.

Do not infer production capacity from development defaults.

## Measurement model

Separate these dimensions:

- request latency;
- queueing time;
- throughput;
- Ruby CPU time;
- wall-clock time;
- database time;
- query count;
- rows/materialized records;
- allocations/retained memory;
- GC cost;
- lock/contention time;
- cache hit/miss behavior;
- external dependency time;
- boot/load time.

Do not claim that one dimension improved when the change only moved cost to another boundary.

For a performance claim, record:

workload
+ environment
+ runtime version
+ data volume
+ metric
+ baseline
+ changed result

No baseline exists: report the absence instead of inventing one.

## Active Record query performance

When diagnosing a slow Rails query, inspect:

1. query count;
2. query duration;
3. SQL shape;
4. predicates and selectivity;
5. joins;
6. eager loading/preloading;
7. selected columns;
8. object materialization;
9. ordering/grouping;
10. pagination strategy;
11. indexes and cardinality;
12. lock/transaction scope;
13. connection-pool pressure.

Prefer query-plan evidence over intuition.

Use `EXPLAIN` or the database's plan tooling when query execution strategy is the question.

Do not solve every query problem with `includes`. Determine whether the real issue is N+1 access, excessive row volume, object materialization, missing indexes, poor predicates, pagination, or contention.

## N+1 detection

Treat N+1 as a query-shape defect.

Typical form:

request
-> load parent records
-> iterate parents
-> lazy-load association for each parent

Preferred fixes depend on the contract:

- `preload` when independent association queries are appropriate;
- `eager_load` when a joined result is required;
- `includes` when Rails should choose based on usage and query shape;
- a direct join/select when only scalar fields are needed;
- a query object when read logic has become complex.

Verify query count or SQL shape rather than merely adding an eager-loading call.

Do not eager-load large associations that are not actually used. Memory and row explosion can be worse than the original query pattern.

## Query-object and read-path design

Use a query object or explicit read boundary when:

- query composition is complex;
- the same read path is reused;
- the query has domain-specific semantics;
- the controller/model would otherwise own a large read operation.

Do not create a query object for a simple one-off relation that is clearer in place.

Keep performance fixes at the boundary owning the cost.

## Pagination and data volume

For large datasets inspect:

- page size;
- OFFSET cost;
- stable ordering;
- keyset/cursor pagination suitability;
- selected columns;
- count queries;
- serialization/rendering cost;
- per-row association access.

Never assume pagination makes a query cheap. Measure the actual generated SQL and returned rows.

## Caching

Caching is a correctness decision as well as a performance decision.

Before adding or changing a cache define:

- key;
- key namespace/version;
- tenant/user/resource identity;
- freshness;
- invalidation;
- expiration;
- serialization;
- storage capacity;
- miss behavior;
- stampede behavior;
- multi-process/distributed semantics;
- failure behavior.

Ask:

> When is this value allowed to be stale?

A cache key must contain every identity dimension required for correctness and tenant isolation.

Do not cache authorization-sensitive or tenant-scoped data with an incomplete key.

Do not introduce a cache solely to hide an unmeasured database/query problem.

## Cache stampede

For expensive values, inspect concurrent misses.

Potential controls include:

- request coalescing;
- distributed locks;
- stale-while-revalidate behavior;
- bounded recomputation;
- prewarming;
- jittered expiration where appropriate.

Choose the simplest mechanism justified by actual contention.

Do not add distributed locking merely because cache stampede is theoretically possible.

## Rails request performance

Decompose a slow request:

network
-> Rack/middleware
-> authentication/authorization
-> controller/application work
-> Active Record
-> serialization/rendering
-> external dependencies
-> response

Use existing Rails instrumentation and application telemetry to identify the dominant boundary.

Do not move work between layers without evidence that the move changes the bottleneck.

## Puma and web concurrency

When changing Puma workers or threads, reason about aggregate capacity:

workers × threads

Then compare that concurrency against:

- CPU;
- memory;
- Active Record connection pool;
- database capacity;
- external API limits;
- queueing behavior;
- lock/contention;
- container/platform limits.

Increasing threads while the database pool remains smaller can increase waiting rather than throughput.

Increasing workers may improve concurrency while exhausting memory.

Do not use generic worker/thread counts without workload evidence.

Use `patterns/rails/puma-capacity.md` for the capacity decision boundary.

## Connection-pool capacity

Database connections are shared capacity, not free concurrency.

Check:

- web worker/thread topology;
- job worker/thread topology;
- multiple Rails processes;
- multiple databases/roles/shards;
- pool size per process;
- database max connections;
- long-running transactions.

Reason about aggregate demand, not only one process.

When a pool timeout occurs, determine whether the root cause is:

- insufficient pool capacity;
- excessive application concurrency;
- long transactions;
- slow queries;
- connection leakage;
- downstream backpressure.

Do not increase pool size blindly. A larger pool can move the bottleneck into the database.

Use `patterns/rails/connection-pool-capacity.md`.

## Background-job performance

For Active Job/background workers inspect:

- batch size;
- serialization;
- query pattern;
- N+1 inside jobs;
- retry amplification;
- job concurrency;
- database pool usage;
- external API latency/rate limits;
- memory growth;
- idempotency;
- queue depth and wait time.

A faster individual job can still reduce system throughput if it increases downstream contention.

When increasing job concurrency, coordinate with `rails-active-job`, `ruby-concurrency`, and `rails-database-engineering`.

## Batching

Use batching for large data processing when memory or transaction size is the limiting factor.

Choose batch size based on evidence:

- query latency;
- memory;
- lock duration;
- database log/replication pressure;
- downstream rate limits.

Avoid giant transactions for unbounded datasets.

Avoid tiny batches that create excessive query overhead.

## Memory and allocations

For Rails-specific memory problems inspect:

- Active Record object materialization;
- oversized result sets;
- serializers/renderers;
- cached objects;
- retained references;
- job batch size;
- worker lifecycle;
- GC pressure.

Use `ruby-performance` for allocation and GC measurement.

Do not replace clear Rails code with mutable low-level code without measured benefit.

## Indexes and query plans

An index is justified by a target query shape and database evidence.

Before adding an index:

1. identify the query;
2. inspect predicate selectivity;
3. inspect existing indexes;
4. inspect the execution plan;
5. consider write/storage cost;
6. consider live-deployment locking/build behavior;
7. verify the new plan after the change.

Use `patterns/rails/production-index.md` for production index changes.

Do not add indexes because a column "looks searchable."

## Performance regression testing

Prefer structural performance contracts when wall-clock timing is unstable:

- query count;
- SQL shape;
- allocation bounds;
- number of external calls;
- batching behavior;
- cache-key behavior;
- algorithmic complexity.

For timing benchmarks, define a representative workload and a threshold with enough warmup/iterations to avoid machine-noise-driven failures.

Do not create CI tests that are so tight they fail because the runner is noisy.

## Performance-safe change procedure

~~~text
reproduce
-> inspect evidence
-> establish baseline
-> identify owning boundary
-> choose smallest suitable pattern
-> implement one targeted change
-> run functional tests
-> run performance measurement
-> inspect secondary effects
-> simplify
-> report evidence
~~~

## Cross-skill coordination

Use these combinations deliberately:

- `ruby-performance`: Ruby CPU, allocations, GC, profiling, benchmark methodology;
- `rails-active-record`: query/persistence implementation;
- `rails-database-engineering`: schema, index, locking, pool/database capacity;
- `rails-active-job`: queue/retry/concurrency semantics;
- `rails-observability`: measurements and request/job telemetry;
- `ruby-concurrency`: threads, contention, race/concurrency reasoning;
- `rails-security`: tenant/auth/cache correctness;
- `rails-test-engineering`: performance regression and deterministic test design.

## Anti-patterns

- optimizing without a workload or baseline;
- adding `includes` without understanding the query shape;
- eager-loading every association;
- adding an index without query-plan evidence;
- increasing Puma threads without DB-pool analysis;
- increasing workers without memory analysis;
- increasing job concurrency without downstream capacity analysis;
- increasing DB pool size until timeout errors disappear;
- caching without freshness/invalidation semantics;
- cache keys that omit tenant/resource identity;
- solving cache stampede with distributed locks without measured contention;
- using OFFSET pagination for very large datasets without inspecting query cost;
- making timing-based CI thresholds unrealistically strict;
- benchmarking only development-sized data;
- treating one faster benchmark as proof of production scalability;
- hiding a bottleneck by moving it to another subsystem.

## Reference example

N+1 eliminated by planning loads up front, with query count asserted in the test rather than hoped for in production.

```ruby
class StatementsController < ApplicationController
  def index
    @statements = current_account.statements
      .includes(:invoice, :customer)   # one planned query, not 1 + N lazy loads
      .order(issued_on: :desc)
      .limit(50)
  end
end

# test/performance/statements_query_test.rb
#   it "renders 50 statements without N+1" do
#     create_list(:statement, 50, account: account)
#     assert_queries(2) { get statements_path } # count the SQL, not the feeling
#   end
#
# Evidence first: Bullet/sql.event trace identifies the association before includes
# is added, and the assertion keeps it from regressing.
```

## Agent review checklist

- [ ] Ruby/Rails/runtime versions inspected
- [ ] workload and symptom identified
- [ ] representative data volume considered
- [ ] bottleneck boundary identified
- [ ] baseline or structural evidence recorded
- [ ] query count/shape reviewed when Active Record is involved
- [ ] query plan reviewed when indexing/query execution is the issue
- [ ] N+1 behavior checked where associations are iterated
- [ ] cache freshness/invalidation/key semantics checked
- [ ] tenant/security identity included in cache keys when applicable
- [ ] Puma concurrency checked against DB/downstream capacity
- [ ] DB pool checked against aggregate concurrency
- [ ] job concurrency checked against DB/external capacity
- [ ] memory/allocation effects considered
- [ ] functional tests pass
- [ ] performance claim re-measured or structurally justified
- [ ] no speculative optimization remains

## Verification

Report evidence in this form:

~~~
workload: ...
environment: ...
baseline: ...
change: ...
after: ...
metric: ...
secondary_effects: ...
trade_off: ...
~~~

If timing evidence is unavailable, explicitly state the structural reason for the conclusion instead.

Never claim "scales better", "faster", "lower memory", or "higher throughput" without measurement or a demonstrated structural property.

## Source foundation

Primary Rails guidance:
- https://guides.rubyonrails.org/caching_with_rails.html
- https://guides.rubyonrails.org/active_record_querying.html
- https://guides.rubyonrails.org/performance_testing.html

Repository-specific foundations:
- skills/ruby-performance/SKILL.md
- skills/rails-active-record/SKILL.md
- skills/rails-database-engineering/SKILL.md
- skills/rails-active-job/SKILL.md
- patterns/rails/cache-boundary.md
- patterns/rails/production-index.md
- patterns/rails/puma-capacity.md
- patterns/rails/connection-pool-capacity.md
- patterns/rails/n-plus-one-review.md
- patterns/rails/query-plan-evidence.md

## Performance-sensitive changes

For performance work:
- establish a workload and baseline before optimizing when practical;
- distinguish latency, throughput, CPU, allocations, GC, database, network, and contention costs;
- use profiling/benchmarking only to answer a concrete question;
- never claim a performance improvement without measurement or a demonstrated structural property;
- do not introduce caching without explicit freshness and invalidation semantics;
- do not increase concurrency without downstream capacity analysis;
- keep performance thresholds stable enough for CI.
