---
name: dependency-direction-contract
description: Dependency Direction Contract
family: architecture
---
# Dependency Direction Contract

## Problem
Uncontrolled dependency direction creates cycles and makes stable policy depend on volatile infrastructure.

## Use when
Changing namespaces/modules or introducing a new subsystem boundary.

## Do not use when
Two components are deliberately symmetric peers with an explicit stable contract.

## Repository inspection
Inspect require/import edges, constant references, service calls, events, and gem/runtime dependencies.

## Implementation procedure
Define allowed direction, reverse dependencies through explicit interfaces where required, and remove cycles incrementally.

## Example

```ruby
# Domain code depends on an interface it owns; infrastructure depends on the
# domain, never the other way round.
module Orders
  # Port owned by the domain.
  class PaymentPort
    def charge(order) = raise(NotImplementedError)
  end

  class Place
    def initialize(payments:) = @payments = payments

    def call(order)
      @payments.charge(order)
      order.update!(status: "placed")
    end
  end
end

# Infrastructure adapts to the domain's port.
class StripePayments < Orders::PaymentPort
  def charge(order) = Stripe::PaymentIntent.create(amount: order.total_cents, currency: "usd", confirm: true)
end
```

## Failure modes
Cycles, infrastructure leakage, bidirectional service calls, shared global state.

## Testing
Run dependency/architecture checks and representative integration tests.

## Review checklist
[ ] direction explicit [ ] cycles inspected [ ] interface justified

## Related skills
rails-staff-principal-architecture, rails-zeitwerk