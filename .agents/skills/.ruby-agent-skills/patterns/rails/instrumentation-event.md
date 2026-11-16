---
name: instrumentation-event
description: Define a stable ActiveSupport::Notifications event without coupling subscribers to domain side effects.
family: rails
---

# Instrumentation Event

## Problem
Application events need observable, reusable contracts for metrics, auditing, and diagnostics.

## Use when
A business/application boundary needs measurement or external observation.

## Implementation procedure
1. Choose a stable event.library name.
2. Define minimal payload fields.
3. Instrument the meaningful boundary.
4. Keep subscribers observational.
5. Define failure/duration semantics.
6. Test event name and required payload fields.

## Example

```ruby
# Producer: name, payload schema, and units are a contract (amount in paise, no card data).
class Checkout
  def charge(order)
    ActiveSupport::Notifications.instrument(
      "charge.checkout", order_id: order.id, amount_paise: order.total_paise, provider: "razorpay"
    ) do |payload|
      payload[:outcome] = Gateway.charge(order).status # :succeeded / :declined
    end
  end
end

# Subscriber: observational only; failures here must not change checkout behavior.
ActiveSupport::Notifications.subscribe("charge.checkout") do |event|
  Metrics.histogram("checkout.charge.duration_ms", event.duration,
                    tags: { provider: event.payload[:provider], outcome: event.payload[:outcome] })
end
```

## Failure modes
- event name changes casually
- high-cardinality payload used as metric dimensions
- subscriber mutates business state
- instrumentation wraps too many tiny methods

## Testing
Subscribe during the test and assert the event contract.

## Review checklist
- stable event name
- minimal payload
- side-effect-free subscriber
- meaningful boundary

## Repository inspection

Inspect the repository's runtime/version, existing conventions, neighboring tests or implementation patterns, and the actual owning boundary before applying this pattern.

## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
## Do not use when

Do not use when no observable event, metric, audit, or diagnostic boundary is required.
