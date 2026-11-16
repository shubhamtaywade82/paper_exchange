---
name: message-delivery-contract
description: Make asynchronous delivery, acknowledgement, duplication, ordering, and replay semantics explicit.
family: rails
---

# Message Delivery Contract

## Problem

A producer and consumer exchange asynchronous messages without an explicit contract for delivery and acknowledgement behavior.

## Use when

Adding or reviewing queues, brokers, streams, events, commands, consumers, or replay workflows.

## Do not use when

The communication is entirely synchronous and no asynchronous delivery layer exists.

## Repository inspection

Inspect broker/queue guarantees, acknowledgement semantics, visibility timeout, retry/dead-letter behavior, partition/key ordering, message identifiers, retention, and consumer persistence.

## Implementation procedure

1. State delivery mode: at-most-once, at-least-once, or effectively-once via deduplication.
2. Define message identity and correlation/causation identifiers.
3. Define acknowledgement timing.
4. Define duplicate behavior.
5. Define ordering guarantees per key/partition when relevant.
6. Define retry/dead-letter/replay behavior.
7. Define schema compatibility during rolling deployment.
8. Test crash/retry/replay paths.

## Example

```markdown
## `order.placed` delivery contract

| Property           | Contract                                                                  |
|--------------------|---------------------------------------------------------------------------|
| Guarantee          | At-least-once (outbox relay → broker). Duplicates are expected.           |
| Identity           | `envelope.id` (UUID), stable across relay retries and replay               |
| Ordering           | Per `order_id` (partition key); none across orders                        |
| Acknowledgement    | Consumer acks after its DB transaction commits                            |
| Retries            | 8 attempts, exponential backoff, then dead-letter `order.placed.dlq`      |
| Retention / replay | 7 days; replay by `id` range, owned by the fulfilment team               |
| Schema             | `schema_version` 2; consumers accept 1 and 2 until 2026-12-31             |
```

## Failure modes

- assuming exactly-once execution
- acknowledging before durable state
- deduplicating only in memory
- assuming global ordering
- retry storm
- poison message loop
- destructive schema change while old messages remain

## Testing

Test duplicate delivery, consumer failure before and after side effects, retry exhaustion, replay, ordering edge cases, and old/new message compatibility.

## Review checklist

- [ ] delivery semantics explicit
- [ ] acknowledgement boundary explicit
- [ ] identity/correlation explicit
- [ ] duplicate behavior explicit
- [ ] ordering assumptions explicit
- [ ] retry/dead-letter/replay explicit
- [ ] rollout compatibility tested

## Related skills

- rails-distributed-systems
- rails-active-job
- rails-observability
- rails-api-integration

## Related patterns

- inbox-deduplication
- idempotent-job
