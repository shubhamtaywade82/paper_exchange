---
name: rails-distributed-systems
description: Use when Rails/Ruby systems cross process, service, host, queue, or datastore boundaries and correctness depends on delivery semantics, consistency, coordination, or failure recovery.
---

# Distributed Systems & Service Architecture

## Purpose

Treat every cross-process or cross-service workflow as a failure boundary.

The design must make ownership, communication, delivery semantics, consistency, retries, idempotency, recovery, observability, and rollout compatibility explicit.

Core flow:

classify boundary
-> define ownership and invariants
-> define message/API contract
-> choose delivery semantics
-> choose consistency model
-> isolate side effects
-> define retry/deduplication/recovery
-> observe state transitions
-> test failure and replay
-> roll out compatibly

This skill composes with:

- rails-api-integration for synchronous APIs/webhooks;
- rails-event-driven-messaging for message envelopes, broker topology, schema evolution, dead-letter/replay, and messaging capacity;
- rails-active-job for asynchronous execution;
- rails-database-engineering for transaction/constraint/locking boundaries;
- ruby-concurrency for in-process coordination;
- rails-observability for correlation and state-transition diagnostics;
- rails-production-runtime for process topology and shutdown behavior;
- rails-security for trust boundaries and credentials.

## Activate when

- splitting a monolith into services or bounded components;
- designing service ownership or a service boundary;
- publishing domain/integration events;
- using queues, brokers, streams, or asynchronous delivery;
- implementing outbox or inbox/deduplication processing;
- reviewing at-least-once or at-most-once delivery;
- coordinating changes across independent datastores;
- designing eventual consistency or read-model propagation;
- implementing sagas or compensating actions;
- introducing a distributed lock/lease;
- handling duplicate, delayed, reordered, or lost messages;
- defining cross-service retries or failure recovery;
- reviewing distributed transaction assumptions;
- planning rolling deployment across service versions.

Do not activate merely because two Ruby classes communicate. The boundary must cross an independent execution, persistence, or trust domain.

## Repository inspection

Inspect:

1. Ruby/Rails versions and process model;
2. application/service ownership boundaries;
3. databases, schemas, replicas, and transaction semantics;
4. Active Job/queue/broker adapter and delivery guarantees;
5. outbound HTTP/event transport and timeout/retry rules;
6. existing idempotency, deduplication, or uniqueness constraints;
7. event/message schemas and versioning;
8. correlation identifiers and tracing conventions;
9. worker concurrency and downstream capacity;
10. deployment/rolling-release topology;
11. failure/retry/dead-letter/replay tooling;
12. operational state/reconciliation jobs;
13. security/authentication between services;
14. tests for duplicate, delayed, reordered, failed, and replayed work.

Never invent a distributed mechanism when an existing database transaction, unique constraint, job primitive, or local abstraction already owns the invariant.

## Boundary classification

Classify the interaction:

### Synchronous service API

A caller waits for a response.

Primary concerns: contract compatibility, timeout, authentication, retries, and partial failure.

Compose with `rails-api-integration`.

### Asynchronous command

One component requests work and completion occurs later.

Primary concerns: delivery, retry, deduplication, acknowledgement, and status visibility.

Compose with `rails-active-job` and delivery patterns.

### Event publication

A producer announces committed state or a domain fact.

Primary concerns: atomic publication, schema evolution, ordering, replay, and consumer independence.

Use the outbox boundary when database commit and publication must be coupled.

### Cross-service workflow

A business operation spans independent transaction boundaries.

Primary concerns: partial success, compensating actions, workflow state, timeouts, and recovery.

Use a saga only when the workflow truly crosses independent transaction owners.

### Shared coordination resource

Multiple processes must coordinate access to one resource.

Prefer a database constraint or atomic state transition when sufficient. A distributed lock is a coordination primitive, not a substitute for ownership or idempotency.

## Ownership and invariants

For every distributed workflow identify:

- system of record;
- authoritative writer;
- invariant owner;
- command owner;
- event producer;
- consumer responsibilities;
- recovery authority.

Do not maintain one business invariant in several services and hope eventual synchronization preserves it.

Persist the invariant where the authoritative writer can enforce it atomically.

## Delivery semantics

Do not assume exactly-once execution.

Make delivery explicit:

- at-most-once;
- at-least-once;
- effectively-once through durable deduplication/idempotency;
- ordered or unordered;
- immediate or eventual.

For at-least-once delivery, duplicate execution is a normal state, not an exceptional state.

Define acknowledgement semantics:

`receive -> persist/claim -> process -> acknowledge`

or the provider/broker-specific equivalent.

Never acknowledge durable work before the required state is safely recorded.

Use `patterns/rails/message-delivery-contract.md`.

## Outbox

When one database transaction must atomically produce application state and a message/event:

`business transaction -> durable outbox row -> asynchronous publisher -> broker -> consumer`

The outbox closes the "database committed but message was not published" gap.

An outbox does not provide exactly-once publication. Publishers may send the same logical event more than once.

Use stable event identity, publication state, retry/replay, and consumer idempotency.

Use `patterns/rails/outbox-publication.md`.

Compose with `transaction-boundary` and `transactional-job-enqueue` rather than duplicating their concerns.

## Inbox and deduplication

For a consumer that may receive duplicates:

`receive -> identify -> durably claim/deduplicate -> apply side effect -> record outcome`

Prefer a database-enforced uniqueness boundary for event/message identity when the consumer datastore owns the side effect.

Do not use an in-memory set or process-local mutex for cross-process deduplication.

Reuse `idempotent-job` when the final execution is an Active Job.

Use `patterns/rails/inbox-deduplication.md`.

## Retries and backpressure

A retry is a load multiplier.

Define:

- retryable failures;
- permanent failures;
- maximum attempts/deadline;
- backoff/jitter;
- queue isolation;
- dead-letter behavior;
- replay authority.

Do not let independently retrying layers multiply without a budget.

Bound concurrency against database pools, provider limits, broker capacity, and service throughput.

Use `rails-active-job`, `ruby-concurrency`, and `rails-performance` for the local capacity boundary.

## Consistency

Choose consistency deliberately:

- strong/read-after-write where user-visible correctness requires it;
- eventual consistency where independent services and asynchronous propagation are acceptable;
- explicit stale-read behavior where replicas/read models may lag.

Define what a caller observes during propagation:

`accepted`, `pending`, `committed`, `available`, or `failed`.

Never hide eventual consistency behind a synchronous-looking API that promises data the system cannot guarantee yet.

Use `patterns/rails/eventual-consistency.md`.

## Sagas

A saga coordinates multiple local transactions without pretending they are one distributed transaction.

Use when a business workflow must span independently owned transaction boundaries.

For each step define:

- forward action;
- success state;
- timeout;
- retry behavior;
- compensation;
- compensation failure/recovery;
- workflow state;
- operator/replay path.

Prefer orchestration when one component must own workflow state and sequencing. Prefer choreography only when independently reacting services keep coupling manageable and observability remains sufficient.

Do not use a saga when one local transaction can enforce the invariant.

Use `patterns/rails/saga-orchestration.md`.

## Distributed locks

Before adding a distributed lock ask whether:

- a unique constraint;
- compare-and-set update;
- row lock;
- queue partition/key;
- concurrency-controlled job;
- single authoritative writer

already solves the invariant.

If a distributed lock is required, define:

- lease duration;
- ownership identity;
- renewal;
- expiration behavior;
- failure after lease loss;
- fencing/token semantics where stale holders are dangerous;
- contention/backoff;
- monitoring.

A lock without fencing can still permit stale owners after pauses or network partitions.

Never treat a lock as proof that a side effect happened exactly once.

Use `patterns/rails/distributed-lock.md`.

## Multi-region deployments

Do not adopt multi-region topology without a concrete residency, latency, or regional-availability requirement. A single region with edge caching satisfies most latency goals.

Before designing for multiple regions, define:

- the requirement single-region cannot satisfy;
- the authoritative write region and replication direction/lag budget;
- the ownership model: single write region, region-partitioned data, or independent stacks with reconciliation;
- data residency boundaries enforced at the storage layer, not by convention;
- region routing and user pinning, and their behavior during failover;
- failover: promotion, fencing against the old primary, RPO/RTO, and conflict handling;
- region-local dependencies (jobs, cache, blob storage) and their failover targets.

Keep synchronous cross-region calls out of user request paths.

Use `patterns/rails/multi-region-data-boundary.md`.

## Ordering and replay

Do not assume message order unless the transport guarantees it for the relevant key/partition.

Where order matters, define one of:

- sequence/version check;
- monotonic state transition;
- partition/key affinity;
- buffering of future events;
- reconciliation from source of truth.

Replay must be safe and observable.

Design event handlers so operators can replay from a durable event/message identity without creating uncontrolled duplicate side effects.

## Failure model

Explicitly model:

- producer crash before commit;
- producer commit before publish;
- publish timeout after broker accepted;
- consumer crash before side effect;
- consumer crash after side effect before acknowledgement;
- duplicate delivery;
- delayed/reordered delivery;
- dependency outage;
- poison message;
- schema incompatibility;
- deployment overlap;
- stale lock holder;
- partial saga completion.

For each failure, define whether the system retries, deduplicates, compensates, reconciles, dead-letters, or requires operator intervention.

## Observability

Propagate a stable correlation/causation context across:

`request -> command -> outbox -> broker -> consumer -> dependency`

Record safe metadata:

- event/message ID;
- correlation/causation ID;
- producer/consumer;
- attempt/retry count;
- state transition;
- latency;
- queue age;
- outcome.

Do not log credentials, raw authorization headers, or unnecessary sensitive payloads.

Distributed debugging requires state-transition evidence, not only exception logs.

Compose with `rails-observability`.

## Rollout compatibility

For message-specific topology/schema/consumer concerns, compose with `rails-event-driven-messaging` rather than expanding this skill with broker-specific mechanics.

During rolling deployment:

- old and new consumers may coexist;
- old messages may arrive at new consumers;
- new messages may arrive at old consumers;
- retries may outlive the deployment that created them.

Therefore evolve message schemas additively first, tolerate unknown fields where appropriate, and delay destructive changes until old traffic/messages are drained.

For cross-service API changes use `rails-api-integration`.

## Testing

Every distributed boundary needs failure-path tests.

At minimum consider:

- duplicate delivery;
- producer failure around commit/publish;
- consumer failure before/after side effect;
- retry exhaustion;
- out-of-order events when relevant;
- replay;
- schema compatibility;
- partial saga completion;
- stale lock/lease behavior;
- eventual-consistency visibility;
- correlation/state-transition observability.

Use deterministic seams and fake transports/brokers where possible. Do not rely on random sleeps to "prove" distributed correctness.

## Reference example

Idempotency at the edge plus an outbox row: the request may retry, the effect must not duplicate.

```ruby
class CreateCharge
  def initialize(request_id, account)
    @request_id = request_id
    @account = account
  end

  def call(amount_cents:)
    # First write records intent; the unique index makes retries converge.
    outbox = OutboxEvent.create_or_find_by!(
      request_id: @request_id,
      kind: "charge.created"
    ) { |event| event.payload = { account_id: @account.id, amount_cents: amount_cents } }

    if outbox.previously_new_record?
      ChargeProcessorJob.perform_later(outbox.id) # effect enqueued exactly once
    end
    Charge.find_by(request_id: @request_id)
  end
end
```

## Agent review checklist

- [ ] boundary crosses an independent process/service/persistence/trust domain
- [ ] authoritative owner and invariant are explicit
- [ ] delivery semantics are explicit
- [ ] exactly-once assumptions are rejected or justified
- [ ] idempotency/deduplication is durable
- [ ] outbox used when commit/publication atomicity is required
- [ ] inbox/deduplication used for duplicate delivery
- [ ] retry budget and backpressure are bounded
- [ ] consistency model is explicit
- [ ] saga exists only where multiple transaction owners require it
- [ ] compensation/recovery semantics are explicit
- [ ] distributed lock is justified over simpler primitives
- [ ] lock lease/fencing behavior is explicit when applicable
- [ ] multi-region ownership/residency/failover contracts are explicit when data spans regions
- [ ] ordering/replay semantics are explicit
- [ ] failure matrix is reviewed
- [ ] correlation/causation identifiers propagate
- [ ] old/new schema compatibility is considered
- [ ] failure/replay tests exist
- [ ] operational replay/reconciliation path is defined

## Anti-patterns

- assuming exactly-once delivery or execution;
- using local Mutex for cross-process correctness;
- using a distributed lock where a database constraint is sufficient;
- adopting multi-region topology without a residency, latency, or availability requirement single-region cannot meet;
- publishing an event after commit with no durable handoff;
- performing the same side effect from duplicate messages without deduplication;
- putting an entire distributed workflow inside one HTTP request;
- using a saga for a workflow one database transaction already owns;
- retrying at every layer without a combined budget;
- treating eventual consistency as an implementation detail when consumers observe stale state;
- acknowledging messages before required durable state;
- assuming message ordering without a transport/key guarantee;
- logging sensitive cross-service payloads;
- destructive message-schema changes during rolling deployment.

## Verification

Verify the owning boundary, not merely helper classes.

For an event publisher:

`transaction -> outbox -> publisher -> message contract`

For a consumer:

`delivery -> dedupe -> side effect -> acknowledgement`

For a saga:

`state machine -> step outcome -> compensation/recovery`

For a lock:

`acquire -> ownership -> lease/fencing -> release/expiry`

Report tested delivery semantics, duplicate behavior, failure paths, consistency, and rollout assumptions.

## Source foundation

- Rails Active Job: https://guides.rubyonrails.org/active_job_basics.html
- Rails Active Record Transactions: https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html
- Rails Active Record Locking: https://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html
- Rails Testing Applications: https://guides.rubyonrails.org/testing.html
- Ruby documentation: https://ruby-doc.org/
- Repository skills: rails-api-integration, rails-active-job, rails-database-engineering, rails-observability, rails-production-runtime, rails-security, ruby-concurrency

## Distributed systems and service architecture changes

For changes crossing process, service, host, queue, broker, or independent datastore boundaries:
- classify the boundary and name the authoritative owner of each invariant;
- inspect API/message schemas, transaction ownership, delivery guarantees, retry/dead-letter behavior, and deployment topology;
- never assume exactly-once execution; make at-least-once duplicate behavior explicit;
- use a database constraint, atomic update, row lock, keyed queue, or single authoritative writer before introducing distributed coordination;
- use an outbox when database commit and message publication must be coupled without a distributed transaction;
- use durable inbox/deduplication for duplicate message delivery and reuse existing idempotent-job semantics for queued execution;
- define acknowledgement timing, replay, ordering, and poison-message behavior;
- bound retries/backpressure across all layers instead of multiplying retry loops;
- make eventual consistency visible through explicit pending/stale semantics and reconciliation where applicable;
- use sagas only when independent transaction owners require cross-step compensation/recovery;
- justify distributed locks over simpler primitives and define lease, ownership, expiry, and fencing behavior when stale holders can mutate state;
- propagate correlation/causation identifiers and record state transitions, not only exceptions;
- preserve old/new message compatibility during rolling deploys;
- test duplicate, delayed, reordered, failed, replayed, and partially completed workflows.
