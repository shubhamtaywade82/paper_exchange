---
name: active-support-notifications-contract
description: Define stable ActiveSupport::Notifications event names, payloads, timing, privacy, and subscriber behavior.
family: rails
---

# Active Support Notifications Contract

## Problem

Custom instrumentation becomes unreliable when event names drift, payloads contain sensitive/high-cardinality data, or subscribers become business logic.

## Use when

- adding custom instrumentation;
- changing notification names/payloads;
- adding subscribers/exporters;
- reviewing instrumentation overhead/privacy.

## Do not use when

- durable domain events or message delivery are the actual problem.

## Repository inspection

Inspect rails-observability conventions, existing event names, subscribers, exporters, logging filters, and tests.

## Implementation procedure

1. Define owner and event name.
2. Define payload schema and units.
3. Keep event names stable and library-oriented.
4. Remove secrets/raw payloads and control cardinality.
5. Keep subscribers observational.
6. Use monotonic subscriptions when elapsed-time accuracy matters.
7. Test event, payload, error, and timing semantics.

## Example

```ruby
# Event name "<action>.<library>", documented payload, units in the key name,
# no PII or high-cardinality values beyond the ids listed.
class Checkout
  def call(order)
    ActiveSupport::Notifications.instrument("checkout.shop", order_id: order.id, line_item_count: order.line_items.size) do
      order.complete!
    end
  end
end

# Subscribers observe; they never change the business outcome.
ActiveSupport::Notifications.subscribe("checkout.shop") do |event|
  StatsD.histogram("checkout.duration_ms", event.duration)
end
```

## Failure modes

- notification used as business event bus;
- high-cardinality payload;
- secret/raw request data;
- subscriber mutates source-of-truth state;
- event name derived from user input;
- wall-clock duration used for precise latency measurement.

## Testing

Test emitted event name, payload fields, exception metadata, and subscriber behavior.

## Review checklist

- [ ] event name stable
- [ ] payload documented
- [ ] cardinality controlled
- [ ] sensitive data filtered
- [ ] subscriber observational
- [ ] timing semantics explicit

## Related skills

- skills/rails-active-support/SKILL.md
- skills/rails-observability/SKILL.md
- skills/rails-event-driven-messaging/SKILL.md
