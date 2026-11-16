---
name: shared-kernel-contract
description: Shared Kernel Contract
family: architecture
---
# Shared Kernel Contract

## Problem
Shared abstractions between domains become coupling sinks when their contract changes at the speed of consumers.

## Use when
Two or more contexts genuinely share a small stable concept or invariant.

## Do not use when
The abstraction is volatile, domain-specific, or owned by one context.

## Repository inspection
Inspect consumers, change history, terminology, and ownership.

## Implementation procedure
Keep the kernel small, stable, and explicitly owned; duplicate volatile concepts instead of sharing them prematurely.

## Example

```ruby
# The shared kernel: tiny, stable value objects every context agrees on.
module SharedKernel
  Money = Data.define(:amount_cents, :currency) do
    def initialize(amount_cents:, currency:)
      raise ArgumentError, "amount must be an Integer" unless amount_cents.is_a?(Integer)
      raise ArgumentError, "unsupported currency" unless %w[INR USD].include?(currency)
      super
    end

    def +(other)
      raise ArgumentError, "currency mismatch" unless currency == other.currency
      with(amount_cents: amount_cents + other.amount_cents)
    end
  end
end

# Not in the kernel: Billing::Invoice, Catalog::Product — they change with their own context.
```

## Failure modes
Kernel becomes common dumping ground, synchronized deploys, unrelated breakage.

## Testing
Test shared contract and representative consumers.

## Review checklist
[ ] small surface [ ] stable semantics [ ] owner [ ] consumer evidence

## Related skills
rails-staff-principal-architecture, ruby-domain-modeling