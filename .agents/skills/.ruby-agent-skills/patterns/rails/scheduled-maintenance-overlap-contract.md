---
name: scheduled-maintenance-overlap-contract
description: Scheduled Maintenance Overlap Contract
family: rails
---
# Scheduled Maintenance Overlap Contract

## Problem
Schedulers can deliver duplicate, delayed, or overlapping maintenance executions during deploys and outages.

## Use when
Recurring maintenance tasks or jobs.

## Do not use when
An operator-only task invoked manually once.

## Repository inspection
Inspect scheduler semantics, retries, deployment lifecycle, locks, and task idempotency.

## Implementation procedure
Design for at-least-once execution, overlap control, delayed execution, and restart behavior.

## Example

```yaml
# config/recurring.yml (Solid Queue)
production:
  expire_unpaid_orders:
    class: ExpireUnpaidOrdersJob
    schedule: every 15 minutes
    queue: maintenance

# app/jobs/expire_unpaid_orders_job.rb
#   class ExpireUnpaidOrdersJob < ApplicationJob
#     # A delayed run must not overlap the next one.
#     limits_concurrency to: 1, key: "expire_unpaid_orders", duration: 30.minutes
#
#     def perform
#       # Idempotent: selects by state, so a duplicate or late run finds nothing to do.
#       Order.pending_payment.where(created_at: ...24.hours.ago).find_each(&:expire!)
#     end
#   end
```

## Failure modes
Concurrent runs, missed cleanup, duplicate side effects, and retry storms.

## Testing
Test duplicate trigger and overlapping invocation behavior.

## Review checklist
[ ] duplicate safe [ ] overlap policy [ ] delayed safe [ ] deploy-safe

## Related skills
rails-operational-tasks-maintenance, rails-active-job, rails-reliability-engineering