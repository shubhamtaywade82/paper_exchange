---
name: data-ownership-contract
description: Data Ownership Contract
family: architecture
---
# Data Ownership Contract

## Problem
Two subsystems mutating the same source of truth create ambiguous invariants and reconciliation problems.

## Use when
Splitting domains/modules or integrating separate subsystems.

## Do not use when
A single bounded component clearly owns the data and invariant.

## Repository inspection
Inspect schema, writers, callbacks, jobs, events, reports, direct SQL, and migrations.

## Implementation procedure
Name authoritative writer/storage owner; expose reads through stable contracts or projections and route mutations through the owner.

## Example

```ruby
# Billing owns invoices.status. Support reads it and asks Billing to change it;
# it never writes the column.
module Billing
  def self.void_invoice!(invoice_id, reason:)
    Invoice.find(invoice_id).update!(status: "void", void_reason: reason)
  end
end

module Support
  class RefundRequest < ApplicationRecord
    def approve!
      Billing.void_invoice!(invoice_id, reason: "support refund ##{id}")
      update!(approved_at: Time.current)
    end
  end
end
```

## Failure modes
Dual writers, conflicting validations, stale replicas treated as authoritative.

## Testing
Search all writers and test invariant preservation across boundaries.

## Review checklist
[ ] authoritative owner [ ] writers inventoried [ ] read contract [ ] no dual mutation

## Related skills
rails-staff-principal-architecture, rails-database-engineering