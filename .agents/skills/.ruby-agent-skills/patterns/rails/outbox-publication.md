---
name: outbox-publication
description: Persist database changes and the intent to publish a message atomically, then publish from durable outbox state.
family: rails
---

# Outbox Publication

## Problem

A transaction can commit application state and still lose a separately executed message publication.

## Use when

A database mutation and publication of an event/command must be coupled without a distributed transaction.

## Do not use when

The event is non-critical, publication may be reconstructed safely from another durable source, or an existing platform already guarantees the required atomic handoff.

## Repository inspection

Inspect the authoritative database, transaction boundaries, event schema, publisher/worker mechanism, uniqueness constraints, retry/dead-letter handling, and observability.

## Implementation procedure

1. Define the stable event identity and payload contract.
2. Write business state and an outbox record in the same transaction.
3. Mark or claim outbox records durably.
4. Publish with finite retry/backoff.
5. Treat publish ambiguity as potentially duplicated delivery.
6. Record publication outcome/attempt metadata.
7. Retain enough state for replay/reconciliation.
8. Make consumers idempotent.

## Example

```ruby
class PlaceOrder
  def call(account:, params:)
    Order.transaction do
      order = account.orders.create!(params)
      # Same transaction as the state change: both commit or neither does.
      OutboxMessage.create!(
        message_id: SecureRandom.uuid, topic: "order.placed",
        payload: { order_id: order.id, total_cents: order.total_cents }
      )
      order
    end
  end
end

# Relay: publishes committed rows; at-least-once, so consumers deduplicate by message_id.
class RelayOutboxJob < ApplicationJob
  def perform
    OutboxMessage.where(published_at: nil).order(:id).limit(500).lock("FOR UPDATE SKIP LOCKED").each do |message|
      Broker.publish(message.topic, message.payload, message_id: message.message_id)
      message.update!(published_at: Time.current)
    end
  end
end
```

## Failure modes

- enqueueing/publishing only after commit with no durable handoff
- deleting outbox state before publication is durably accepted
- using random event identity on every retry
- assuming publisher retry means exactly-once delivery
- holding database transactions open across network calls

## Testing

Test commit/rollback, publisher crash before/after send, ambiguous send timeout, duplicate publication, replay, and schema compatibility.

## Review checklist

- [ ] business state and outbox write share one transaction
- [ ] stable event identity
- [ ] bounded publisher retry
- [ ] duplicate publication tolerated
- [ ] replay/reconciliation path exists
- [ ] consumer idempotency exists

## Related skills

- rails-distributed-systems
- rails-database-engineering
- rails-active-job
- rails-observability

## Related patterns

- transaction-boundary
- transactional-job-enqueue
- inbox-deduplication
- message-delivery-contract
