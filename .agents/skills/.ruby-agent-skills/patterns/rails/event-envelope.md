---
name: event-envelope
description: Define a stable message envelope that carries identity, type, version, time, and correlation metadata separately from the domain payload.
family: rails
---

# Event Envelope

## Problem

Messages carry inconsistent metadata, making retries, replay, correlation, and compatibility difficult to reason about.

## Use when

Multiple asynchronous messages share operational metadata or are consumed by independent services.

## Do not use when

A transport/framework already provides an equivalent stable envelope and adding another layer would duplicate its contract.

## Repository inspection

Inspect existing event serializers, broker metadata, message IDs, correlation/tracing conventions, schema/version fields, and security filtering.

## Implementation procedure

1. Define message identity and uniqueness scope.
2. Define message type and schema version.
3. Define occurred-at and producer metadata.
4. Propagate correlation and causation identifiers.
5. Separate envelope metadata from payload.
6. Preserve identity across retry and replay.
7. Define tenant/partition key semantics where required.
8. Validate the envelope before domain processing.

## Example

```ruby
# One envelope for every published message; payload stays domain-specific.
class EventEnvelope
  SCHEMA_VERSION = 1

  def self.build(type:, payload:, correlation_id:, causation_id: nil)
    {
      "id" => SecureRandom.uuid,              # stable across retries/replay
      "type" => type,                         # e.g. "order.placed"
      "schema_version" => SCHEMA_VERSION,
      "occurred_at" => Time.current.utc.iso8601(6),
      "producer" => "shop-web",
      "correlation_id" => correlation_id,     # the originating request/job
      "causation_id" => causation_id,         # the message that caused this one
      "payload" => payload
    }
  end
end

EventEnvelope.build(
  type: "order.placed",
  payload: { "order_id" => 42, "total_cents" => 1_999 },
  correlation_id: Current.request_id
)
```

## Failure modes

- new ID generated for every retry
- payload and transport metadata mixed together
- missing schema version
- correlation lost across hops
- sensitive data placed in operational metadata
- message identity not unique within its scope

## Testing

Test envelope validation, stable identity across retries, correlation propagation, version handling, and missing/invalid metadata.

## Review checklist

- [ ] identity scope explicit
- [ ] type/version explicit
- [ ] correlation/causation explicit
- [ ] payload separated from metadata
- [ ] retry/replay preserves identity
- [ ] sensitive fields excluded

## Related skills

- rails-event-driven-messaging
- rails-distributed-systems
- rails-observability
- rails-security
