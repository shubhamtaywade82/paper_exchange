---
name: maintenance-lock-contract
description: Maintenance Lock Contract
family: rails
---
# Maintenance Lock Contract

## Problem
Concurrent operators or schedulers can execute the same mutation simultaneously.

## Use when
Exclusive maintenance tasks or recurring jobs that cannot safely overlap.

## Do not use when
A fully idempotent operation designed for unrestricted concurrency.

## Repository inspection
Inspect existing advisory locks, Redis/DB locks, leases, job concurrency, and deployment topology.

## Implementation procedure
Choose the repository's established lock mechanism; define owner identity, timeout, and stale-lock recovery.

## Example

```ruby
# PostgreSQL advisory lock: a second run exits instead of overlapping.
namespace :billing do
  desc "Generate monthly invoices"
  task generate_invoices: :environment do
    lock_key = Zlib.crc32("billing:generate_invoices")
    acquired = ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_lock(#{lock_key})")
    abort "another run holds the lock; exiting" unless acquired

    begin
      Account.billable.find_each { |account| Invoices::Generate.call(account, period: Date.current.prev_month) }
    ensure
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{lock_key})")
    end
  end
end
# Invoices::Generate is itself idempotent (unique index on account_id + period).
```

## Failure modes
Double execution, deadlocks, permanent locks, or false ownership.

## Testing
Test lock acquisition, contention, timeout, and cleanup.

## Review checklist
[ ] lock mechanism [ ] owner [ ] timeout [ ] stale recovery

## Related skills
rails-operational-tasks-maintenance, rails-reliability-engineering