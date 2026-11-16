---
name: modular-monolith-boundary
description: Modular Monolith Boundary Contract
family: architecture
---
# Modular Monolith Boundary Contract

## Problem
Premature process decomposition adds distributed failure without solving the underlying coupling problem.

## Use when
A large Rails application needs stronger ownership and dependency boundaries but independent deployment is not yet required.

## Do not use when
Independent scaling/deployment/failure isolation is a proven requirement for the capability.

## Repository inspection
Inspect deployment topology, data ownership, coupling, runtime constraints, and boundary candidates.

## Implementation procedure
Create in-process modules with explicit public contracts and enforce forbidden dependencies before considering process extraction.

## Example

```ruby
# One process, explicit module boundaries. Billing exposes a small public API;
# other modules may not reach into Billing::Internal.
module Billing
  def self.charge_for(order_id:, amount_cents:)
    Internal::ChargeOrder.call(order_id:, amount_cents:)
  end

  module Internal
    class ChargeOrder
      def self.call(order_id:, amount_cents:) = Charge.create!(order_id:, amount_cents:)
    end
  end
end

# Enforced in CI (packwerk package.yml for app/packages/billing):
#   enforce_privacy: true
#   public_path: app/public
#   dependencies: ["app/packages/accounts"]
```

## Failure modes
Distributed monolith, namespace-only modules, uncontrolled cross-module table access.

## Testing
Test module contracts and run dependency-direction checks.

## Review checklist
[ ] in-process boundary [ ] public contract [ ] forbidden edges [ ] extraction path

## Related skills
rails-staff-principal-architecture, rails-engines-railties-engineering