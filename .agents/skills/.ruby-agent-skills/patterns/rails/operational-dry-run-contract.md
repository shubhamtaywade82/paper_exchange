---
name: operational-dry-run-contract
description: Operational Dry-Run Contract
family: rails
---
# Operational Dry-Run Contract

## Problem
Operators cannot validate scope before a destructive maintenance operation.

## Use when
Cleanup, backfill, repair, migration-support, or high-volume mutation task.

## Do not use when
A tiny, naturally atomic operation with negligible blast radius.

## Repository inspection
Inspect selection predicate, mutation path, reporting needs, and operator workflow.

## Implementation procedure
Separate selection/reporting from mutation and expose a dry-run or preview mode when useful.

## Example

```ruby
namespace :users do
  desc "Delete users inactive for 3 years (DRY_RUN=0 to execute)"
  task purge_inactive: :environment do
    dry_run = ENV.fetch("DRY_RUN", "1") != "0" # safe by default
    scope = User.where(last_seen_at: ...3.years.ago).where.not(role: "admin")

    puts "#{scope.count} users match; sample ids: #{scope.limit(10).pluck(:id).join(', ')}"
    next puts("dry run: no changes") if dry_run

    scope.find_each(&:destroy!) # destroy: dependent data and audit callbacks run
    puts "remaining: #{scope.count}"
  end
end
```

## Failure modes
Dry-run accidentally mutates, preview does not represent actual scope, or reporting leaks sensitive data.

## Testing
Test dry-run produces zero writes while reporting expected scope.

## Review checklist
[ ] dry-run no writes [ ] same selection predicate [ ] safe reporting

## Related skills
rails-operational-tasks-maintenance