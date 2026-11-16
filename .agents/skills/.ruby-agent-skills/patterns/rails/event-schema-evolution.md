---
name: event-schema-evolution
description: Evolve event and message schemas while old and new producers/consumers coexist.
family: rails
---

# Event Schema Evolution

## Problem

Asynchronous messages can remain in queues or logs after the producer/consumer deployment that created them.

## Use when

Adding fields, changing event meaning, versioning messages, or migrating producers and consumers.

## Do not use when

The message contract is private, ephemeral, and no old messages can survive across deployment boundaries.

## Repository inspection

Inspect schema/version strategy, serializer behavior, retained messages, consumer versions, replay tooling, and rolling deployment order.

## Implementation procedure

1. Capture the current wire contract.
2. Classify the change as additive, compatible, or breaking.
3. Prefer additive optional fields when semantics allow.
4. Keep consumers tolerant of unknown fields.
5. Introduce a new version/type for real breaking semantics.
6. Deploy compatible consumers before producers when required.
7. Drain/migrate old messages before removing support.
8. Test old producer/new consumer and new producer/old consumer as applicable.

## Example

```ruby
# Consumers accept every schema version still retained in the queue/log.
class OrderPlacedConsumer
  def call(envelope)
    payload = envelope.fetch("payload")
    case envelope.fetch("schema_version")
    when 1
      # v1 had integer rupees; v2 added total_cents and currency.
      record(order_id: payload.fetch("order_id"), total_cents: payload.fetch("total") * 100, currency: "INR")
    when 2
      record(order_id: payload.fetch("order_id"), total_cents: payload.fetch("total_cents"),
             currency: payload.fetch("currency"))
    else
      raise UnsupportedSchema, "order.placed v#{envelope['schema_version']}" # routed to dead letter
    end
  end

  class UnsupportedSchema < StandardError; end

  private

  def record(**attrs) = OrderLedgerEntry.upsert(attrs, unique_by: :order_id)
end
```

## Failure modes

- changing field type in place
- making optional fields mandatory
- changing event meaning without versioning
- removing old consumers before retained messages drain
- assuming a schema registry makes incompatible changes safe

## Testing

Test representative old/new payloads in both deployment directions that can coexist. Test replay of historical versions.

## Review checklist

- [ ] compatibility classification explicit
- [ ] versioning strategy explicit
- [ ] old messages remain readable
- [ ] unknown fields handled safely
- [ ] rollback/rolling deployment considered
- [ ] historical replay tested

## Related skills

- rails-event-driven-messaging
- rails-distributed-systems
- rails-api-integration
- rails-test-engineering

## Related patterns

- event-envelope
- message-delivery-contract
