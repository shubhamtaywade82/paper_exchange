---
name: rails-event-driven-messaging
description: Use when Rails/Ruby applications publish, consume, route, replay, evolve, or operate asynchronous events, commands, queues, brokers, or streams.
---

# Event-Driven Architecture & Messaging Engineering

## Purpose

Treat asynchronous messaging as an executable platform contract rather than a transport detail.

A reliable event-driven system makes message identity, schema, ownership, partitioning/order, delivery, acknowledgement, retry, dead-letter, replay, observability, and capacity explicit.

Core flow:

classify message
-> identify producer/consumer ownership
-> define envelope and schema
-> choose delivery and ordering semantics
-> choose partitioning/consumer model
-> define handler boundary
-> define retry/dead-letter/replay
-> instrument message lifecycle
-> size broker/consumer capacity
-> test duplicates/failures/compatibility
-> operate and evolve safely

Compose this skill with:

- rails-distributed-systems for distributed ownership and consistency;
- rails-api-integration for synchronous integration contracts;
- rails-active-job for Rails queue execution;
- rails-database-engineering for durable inbox/outbox state;
- rails-observability for message lifecycle diagnostics;
- rails-production-runtime for worker/process topology;
- ruby-concurrency for bounded consumer concurrency;
- rails-security for trust and secret boundaries;
- rails-test-engineering for deterministic message tests.

## Activate when

- publishing domain/integration events;
- consuming messages from queues, brokers, or streams;
- designing topics, queues, routing keys, partitions, or consumer groups;
- choosing ordering or parallel-consumption semantics;
- evolving event/message schemas;
- introducing dead-letter queues or poison-message handling;
- building replay or backfill tooling;
- reviewing consumer lag, throughput, or broker capacity;
- adding message tracing/correlation;
- defining event envelopes and metadata;
- changing retry/acknowledgement behavior;
- migrating between message transports;
- designing event-driven workflows.

Do not activate merely because a background job exists. Use this skill when the message itself is an architectural integration boundary.

## Repository inspection

Inspect:

1. Ruby/Rails/runtime versions;
2. queue/broker/stream technology and adapter;
3. message transport guarantees: delivery, ordering, retention, visibility/ack;
4. producer/consumer ownership and service boundaries;
5. event/message schemas and serializer/versioning convention;
6. topic/queue/routing-key/partition conventions;
7. consumer-group or worker topology;
8. retry, dead-letter, replay, and poison-message tooling;
9. outbox/inbox/idempotency implementations;
10. correlation/tracing and structured logging;
11. worker concurrency, database pools, and provider limits;
12. deployment/rolling-release compatibility;
13. security/authentication/encryption at the messaging boundary;
14. existing fixtures, contract tests, and integration tests.

Do not assume Kafka-style semantics, FIFO semantics, visibility timeouts, or exactly-once guarantees unless the actual transport/version documents and configuration support them.

## Message taxonomy

Classify the message before implementation:

### Command

An instruction for a specific consumer to perform work.

Commands normally have one intended owner.

### Event

A fact that something happened.

Events should not encode a hidden command contract such as "please do X" unless that is intentionally the model.

### Notification/integration event

A published fact intended for other systems.

The producer owns the fact; consumers own their reactions.

### Scheduled/retry message

A delivery mechanism for deferred work.

Keep retry metadata distinct from business event semantics.

Do not overload one message type to serve command, event, and internal retry roles without an explicit contract.

## Envelope contract

Use a stable envelope when the transport/application contract benefits from shared metadata.

Typical fields:

`message_id`, `message_type`, `schema_version`, `occurred_at`, `producer`, `correlation_id`, `causation_id`, `tenant/partition key`, and the typed payload.

Keep transport metadata separate from domain payload.

Message identity must remain stable across retry/replay of the same logical message.

Never generate a new logical message ID for every delivery attempt.

Use `patterns/rails/event-envelope.md`.

## Schema evolution

Consumers may run older and newer code simultaneously.

Prefer additive evolution:

- add optional fields;
- preserve existing meaning;
- tolerate unknown fields where safe;
- do not silently change field type or semantics;
- use explicit schema versions when the wire contract genuinely changes.

When a breaking change is unavoidable:

1. introduce a new version/type;
2. keep old consumers working during rollout;
3. dual-publish or translate only when justified;
4. migrate consumers;
5. drain/replay old messages as required;
6. remove the old schema only after compatibility evidence exists.

Use `patterns/rails/event-schema-evolution.md`.

Do not use a schema registry as permission to make incompatible changes.

## Topic, queue, routing-key, and partition design

Choose topology around ownership and workload.

Define:

- producer ownership;
- intended consumers;
- fan-out semantics;
- retention;
- replay requirements;
- partition/routing key;
- maximum acceptable lag;
- message size expectations;
- ordering scope.

A partition/routing key should preserve ordering for the entity whose transitions require order without creating a single global bottleneck unnecessarily.

Do not partition on a high-cardinality field merely because it distributes load; verify the ordering requirement and hot-key risk first.

Use `patterns/rails/consumer-group-partitioning.md`.

## Consumer groups and parallelism

A consumer group distributes work among active consumers according to transport semantics.

Before increasing consumer count, evaluate:

- partition/shard count;
- downstream concurrency;
- database connection pool;
- external API rate limits;
- CPU/memory;
- message processing latency;
- ordering constraints;
- rebalancing behavior;
- shutdown/recovery semantics.

A consumer group does not make the handler idempotent.

Do not scale consumers beyond the transport's parallelism or downstream capacity.

## Handler boundary

Keep the message adapter responsible for:

- decode;
- schema validation;
- authentication/integrity when applicable;
- envelope validation;
- correlation extraction;
- deduplication/claim;
- dispatch to application/domain behavior;
- acknowledgement outcome mapping.

Do not expose broker-specific payload objects throughout the domain.

The handler should be safe to invoke from replay and should answer:

`What happens if this message is delivered twice?`

## Acknowledgement

Acknowledgement is part of correctness.

Define when a message becomes eligible for acknowledgement:

- after durable claim;
- after durable state transition;
- after external side effect with idempotency;
- after complete handler success.

Do not acknowledge merely because the message parsed successfully.

Do not acknowledge a poison message indefinitely without routing it to an explicit terminal/review path.

Use the transport-specific acknowledgement contract; never invent "ack after enqueue" semantics without verifying what durability that represents.

## Retry policy

Retry based on failure class:

Retryable:
- transient dependency outage;
- throttling;
- bounded connection/timeout failure;
- temporary broker/platform failure.

Usually permanent:
- schema incompatibility;
- invalid authentication;
- malformed payload;
- deterministic domain rejection;
- missing required reference that cannot become valid.

Every retry policy needs:

- maximum attempts;
- deadline or retention bound;
- backoff/jitter;
- queue isolation if necessary;
- terminal destination;
- replay authority.

Do not retry a poison message forever.

Coordinate retry budgets across broker, consumer framework, HTTP clients, and Active Job.

## Dead-letter queues and poison messages

A dead-letter mechanism is a containment and recovery boundary.

Capture safe metadata:

- original message ID;
- message type/schema;
- source topic/queue;
- first-seen time;
- attempts;
- failure class;
- correlation/causation ID;
- handler version.

Do not dump credentials or unnecessary sensitive payloads into dead-letter storage.

Define:

- who may inspect/replay;
- retention;
- remediation;
- replay safety;
- whether the original timestamp/identity is preserved.

Use `patterns/rails/dead-letter-replay.md`.

## Replay and backfill

Replay is a production capability, not a test trick.

A replay system must define:

- selection criteria;
- immutable message identity;
- destination/consumer scope;
- rate limit;
- ordering;
- duplicate behavior;
- side-effect safety;
- operator authorization;
- audit trail;
- stop/resume semantics.

Prefer replaying from a durable source of truth or retained message log.

Do not blindly republish millions of events at production consumer speed without capacity control.

A replay should not accidentally trigger user-visible effects twice.

## Message observability

Trace a message across:

`producer -> broker -> consumer -> handler -> dependency`

Record:

- message ID;
- correlation ID;
- causation ID;
- producer/consumer;
- message type/schema version;
- enqueue/publish timestamp;
- processing start/end;
- attempt;
- outcome;
- queue age/lag where available.

Metrics should distinguish:

- publish rate;
- consume rate;
- success/failure;
- retry rate;
- dead-letter count;
- consumer lag;
- handler latency;
- oldest message age.

Avoid logging entire payloads by default.

Use `patterns/rails/message-observability.md`.

## Capacity and backpressure

Messaging moves work; it does not remove capacity constraints.

Model:

`arrival rate -> queue growth -> consumer throughput -> dependency capacity`

Watch for:

- consumer lag;
- hot partitions;
- queue depth;
- database pool exhaustion;
- downstream throttling;
- memory pressure;
- retry amplification.

Use bounded concurrency and backpressure rather than unbounded consumer parallelism.

Use `patterns/rails/broker-capacity.md`.

## Security

Treat messages as untrusted integration input unless the transport/authentication guarantees are explicitly established.

Verify:

- producer/service identity;
- topic/queue permissions;
- payload authenticity/integrity;
- tenant isolation;
- encryption requirements;
- secret handling;
- replay authorization.

Do not treat correlation IDs or message IDs as secrets.

Do not place credentials or bearer tokens in message payloads.

## Rolling deployments

During a rollout:

- old consumers may read new messages;
- new consumers may read old messages;
- replay may execute after the original deployment;
- dead-letter items may outlive the producer code.

Therefore support old/new schema coexistence and keep handlers compatible until old messages are drained or explicitly migrated.

Never deploy a consumer that cannot safely parse messages still present in the queue/log.

## Testing

Test the message boundary rather than only the service object.

Minimum cases:

- valid envelope;
- invalid schema;
- unknown/new optional field;
- incompatible version;
- duplicate message;
- consumer failure before side effect;
- consumer failure after side effect;
- retry exhaustion;
- dead-letter routing;
- replay;
- out-of-order delivery where relevant;
- hot-key/partition behavior where relevant;
- correlation propagation;
- shutdown/restart recovery.

Use fake transports or broker test harnesses where possible. Do not rely on arbitrary sleeps for delivery timing.

## Reference example

Domain events over Active Support notifications with a queue-backed subscriber: publishing is synchronous, effects are not.

```ruby
module Billing
  class Invoice
    def mark_paid!(at: Time.current)
      update!(paid_at: at)
      ActiveSupport::Notifications.instrument(
        "invoice.paid",
        invoice_id: id, account_id: account_id, paid_at: at
      )
    end
  end
end

Rails.application.config.to_prepare do
  ActiveSupport::Notifications.subscribe("invoice.paid") do |event|
    # Subscriber stays trivial; work is enqueued so publish() never blocks.
    InvoicePaidHandlerJob.perform_later(event.payload.slice(:invoice_id, :account_id))
  end
end
```

## Agent review checklist

- [ ] message classified as command/event/notification/retry
- [ ] envelope and identity defined
- [ ] producer/consumer ownership explicit
- [ ] schema versioning strategy explicit
- [ ] partition/routing key justified
- [ ] ordering scope explicit
- [ ] consumer-group parallelism bounded
- [ ] acknowledgement boundary explicit
- [ ] retry classification and budget explicit
- [ ] poison-message handling explicit
- [ ] dead-letter retention/replay policy explicit
- [ ] replay authorization and rate limit explicit
- [ ] correlation/causation propagated
- [ ] payload logging minimized
- [ ] broker/consumer capacity measured or bounded
- [ ] old/new rolling compatibility verified
- [ ] duplicate/failure/replay tests exist

## Anti-patterns

- treating a queue as a database;
- assuming exactly-once processing;
- generating new event identity on retry;
- mixing command and event semantics without a contract;
- using one global ordering key for the whole system;
- scaling consumers without checking partitions/database/API capacity;
- retrying poison messages indefinitely;
- dead-lettering without replay ownership;
- replaying without idempotent handlers;
- logging sensitive message payloads;
- destructive schema changes while old messages remain;
- acknowledging before durable work completion;
- allowing every application layer to depend directly on broker-specific APIs.

## Verification

For producers:

`domain commit -> message identity/schema -> publication -> observability`

For consumers:

`decode -> validate -> dedupe -> handler -> acknowledgement`

For failure handling:

`retry -> backoff -> dead-letter -> operator review -> controlled replay`

For capacity:

`arrival rate -> consumer throughput -> dependency capacity -> lag/backpressure`

Report schema compatibility, duplicate safety, delivery/ack semantics, replay behavior, observability, and capacity assumptions.

## Source foundation

- Rails Active Job: https://guides.rubyonrails.org/active_job_basics.html
- Rails Active Record Transactions: https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html
- Rails Testing Applications: https://guides.rubyonrails.org/testing.html
- Ruby documentation: https://ruby-doc.org/
- Repository skills: rails-distributed-systems, rails-api-integration, rails-active-job, rails-observability, rails-production-runtime, ruby-concurrency, rails-security

## Event-driven messaging changes

For queue, broker, stream, event, and message changes:
- classify the message as command, event, notification, or retry/control message;
- resolve actual transport guarantees for delivery, ordering, retention, acknowledgement, and partitioning;
- define stable message identity, envelope metadata, schema version, correlation, and causation;
- preserve old/new message compatibility during rolling deployments and replay;
- choose routing/partition keys from ordering requirements and hot-key evidence;
- bound consumer concurrency against partitions, database pools, downstream API limits, CPU, and memory;
- make acknowledgement timing explicit and never acknowledge before required durable work;
- classify retryable versus permanent failures and terminate poison-message loops;
- define dead-letter ownership, retention, remediation, authorization, and controlled replay;
- preserve original message identity during retry/replay;
- instrument publish, queue age/lag, processing, retries, dead-letter, and replay state without logging sensitive payloads;
- test duplicate delivery, failures before/after side effects, schema compatibility, dead-letter routing, replay, ordering, and restart/rebalance behavior.
