---
name: application-service-boundary
description: Application Service Boundary Contract
family: architecture
---
# Application Service Boundary Contract

## Problem
Application services become thin wrappers or giant workflow containers when ownership is not explicit.

## Use when
Extracting a business workflow or orchestration boundary.

## Do not use when
A trivial one-object operation belongs naturally to the existing model/domain object.

## Repository inspection
Inspect controllers, models, policies, jobs, tasks, and existing services.

## Implementation procedure
Make orchestration explicit; keep domain invariants with their owner and authorize at the correct boundary.

## Example

```ruby
# Earns a service: coordinates several aggregates and an external call, and
# owns the transaction boundary for that workflow.
class Orders::Refund
  def initialize(order, amount_cents:, actor:)
    @order = order
    @amount_cents = amount_cents
    @actor = actor
  end

  def call
    raise Authorization::Forbidden unless RefundPolicy.new(@actor, @order).allowed?

    refund = Order.transaction do
      @order.lock!
      @order.refunds.create!(amount_cents: @amount_cents, actor: @actor)
    end
    PaymentsGateway.refund(@order.payment_id, @amount_cents, idempotency_key: "refund-#{refund.id}")
    refund
  end
end
# Does not earn one: Orders::Rename that only calls order.update!(name:).
```

## Failure modes
God services, pass-through services, hidden transaction ownership, duplicated authorization.

## Testing
Test orchestration plus domain invariant at their owning boundaries.

## Review checklist
[ ] orchestration [ ] invariant owner [ ] transaction owner [ ] auth boundary

## Related skills
rails-staff-principal-architecture, ruby-service-objects, rails-authorization