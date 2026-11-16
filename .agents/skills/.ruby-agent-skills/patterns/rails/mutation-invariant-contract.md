---
name: mutation-invariant-contract
description: Maintenance Mutation Invariant Contract
family: rails
---
# Maintenance Mutation Invariant Contract

## Problem
Bulk maintenance can bypass callbacks, validations, authorization, or audit behavior that business invariants depend on.

## Use when
Using update_all, delete_all, direct SQL, or low-level writes in maintenance.

## Do not use when
Operations that use normal model behavior and have no bypass.

## Repository inspection
Inspect callbacks, validations, constraints, audit events, jobs, counters, timestamps, and authorization assumptions.

## Implementation procedure
Document intentionally bypassed behavior and reproduce any required invariant explicitly or choose safer writes.

## Example

```ruby
# update_all skips validations and callbacks, so the task restates what it bypasses.
namespace :orders do
  desc "Expire unpaid orders older than 24h"
  task expire_unpaid: :environment do
    cutoff = 24.hours.ago
    Order.pending_payment.where(created_at: ...cutoff).in_batches(of: 500) do |batch|
      ids = batch.pluck(:id)
      Order.transaction do
        # Invariant normally enforced by Order#expire!: stock release + audit + status.
        StockReservation.where(order_id: ids).delete_all
        batch.update_all(status: "expired", expired_at: Time.current, updated_at: Time.current)
        AuditEvent.insert_all(ids.map { |id| { subject_type: "Order", subject_id: id, action: "expired", created_at: Time.current } })
      end
    end
  end
end
# Database check constraint keeps status within the allowed set for every writer.
```

## Failure modes
Corrupted counters, missing audit events, orphaned data, authorization bypass, stale denormalizations.

## Testing
Verify database and application invariants before and after representative mutations.

## Review checklist
[ ] invariants inventoried [ ] bypass justified [ ] recovery verified

## Related skills
rails-operational-tasks-maintenance, rails-active-record, rails-authorization