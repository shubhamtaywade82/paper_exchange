---
name: bounded-context-contract
description: Bounded Context Contract
family: architecture
---
# Bounded Context Contract

## Problem
Different domains become tightly coupled when terminology, invariants, or ownership are shared without a boundary.

## Use when
Separating materially different business capabilities inside a Rails application.

## Do not use when
A capability shares vocabulary, invariants, and change ownership naturally.

## Repository inspection
Inspect domain concepts, model relationships, services, policies, events, and team ownership.

## Implementation procedure
Define context vocabulary, invariants, owned models, external contracts, and permitted dependencies.

## Example

```ruby
# "Customer" means different things in Billing and Support; each context owns
# its model and they talk through a small, explicit translation.
module Billing
  class Customer < ApplicationRecord
    self.table_name = "billing_customers" # payment methods, tax ids, invoices
  end
end

module Support
  class Requester < ApplicationRecord
    self.table_name = "support_requesters" # contact preferences, SLA tier

    def self.for_account(account_id)
      find_or_create_by!(account_id: account_id)
    end
  end
end
# Support never reads billing_customers; it asks Billing.balance_due?(account_id).
```

## Failure modes
Context boundary by folder only, duplicated contradictory rules, shared mutable tables without ownership.

## Testing
Test context contracts and forbidden cross-context behavior where practical.

## Review checklist
[ ] vocabulary [ ] invariant owner [ ] contract [ ] dependency rules

## Related skills
rails-staff-principal-architecture, rails-domain-modeling