---
name: modular-monolith-before-service-split
description: Modular Monolith Before Service Split
family: stack-minimality
---
# Modular Monolith Before Service Split

## Problem
A service split adds latency, serialization, deployment, compatibility, observability, and partial-failure costs.

## Use when
Separating Rails domains or proposing a microservice.

## Do not use when
Independent deployment, scaling, ownership, regulatory isolation, or failure isolation is a concrete requirement.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Create an explicit in-process boundary first. Extract a network boundary only when its operational benefit outweighs distributed-system cost.

## Example

```ruby
# A module boundary inside the monolith: one public entry point, private
# internals, no network hop, same transaction and deploy.
module Billing
  def self.charge(order)
    Charge.new(order).call
  end

  class Charge
    def initialize(order)
      @order = order
    end

    def call
      Invoice.create!(order: @order, amount_cents: @order.total_cents)
    end
  end
  private_constant :Charge
end

Billing.charge(order) # other modules call only the public entry point
```

## Failure modes
Distributed monoliths, dual data ownership, synchronous fan-out, and service extraction by fashion.

## Testing
Test module contracts; network extraction also needs failure and compatibility tests.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
rails-staff-principal-architecture, rails-distributed-systems, rails-api-integration, stack-minimality
