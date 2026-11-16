---
name: idempotent-maintenance-contract
description: Idempotent Maintenance Contract
family: rails
---
# Idempotent Maintenance Contract

## Problem
Interrupted or repeated maintenance can duplicate work or corrupt state when reruns are unsafe.

## Use when
Backfills, repair tasks, reconciliation, cleanup, and recurring maintenance.

## Do not use when
A one-time transactional change whose database constraint guarantees exact-once semantics.

## Repository inspection
Inspect selection predicate, completion marker, unique constraints, and rerun behavior.

## Implementation procedure
Make completion detectable and repeated execution converge on the intended state.

## Example

```ruby
# Rerunnable: selects only unprocessed rows, so a crash midway resumes cleanly.
namespace :data do
  desc "Normalize legacy phone numbers (safe to rerun)"
  task normalize_phones: :environment do
    scope = Customer.where(phone_normalized_at: nil).where.not(phone: nil)
    total = scope.count
    done = 0
    scope.in_batches(of: 1_000) do |batch|
      batch.each do |customer|
        customer.update_columns(phone: PhoneNumber.normalize(customer.phone), phone_normalized_at: Time.current)
      end
      done += batch.size
      puts "normalized #{done}/#{total}"
    end
    remaining = Customer.where(phone_normalized_at: nil).where.not(phone: nil).count
    abort "postcondition failed: #{remaining} remaining" unless remaining.zero?
  end
end
```

## Failure modes
Double processing, duplicated records, repeated side effects, or impossible resume state.

## Testing
Run the task twice and assert the second run causes no unintended new effects.

## Review checklist
[ ] repeatable [ ] completion detectable [ ] side effects bounded

## Related skills
rails-operational-tasks-maintenance, rails-database-engineering