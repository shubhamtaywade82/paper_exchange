---
name: environment-gate-contract
description: Operational Environment Gate Contract
family: rails
---
# Operational Environment Gate Contract

## Problem
A destructive task can run against the wrong environment when safety relies on operator memory.

## Use when
Any task that mutates production or sensitive data.

## Do not use when
Read-only diagnostic tasks with no environment-specific risk.

## Repository inspection
Inspect Rails.env usage, deployment configuration, required environment variables, and existing production guards.

## Implementation procedure
Add explicit environment/precondition checks and fail before side effects when requirements are absent.

## Example

```ruby
# lib/tasks/maintenance.rake
namespace :maintenance do
  desc "Purge expired guest carts (requires CONFIRM=purge-guest-carts outside development)"
  task purge_guest_carts: :environment do
    unless Rails.env.development? || ENV["CONFIRM"] == "purge-guest-carts"
      abort "Refusing to run in #{Rails.env}: set CONFIRM=purge-guest-carts"
    end

    scope = Cart.guest.where(updated_at: ...30.days.ago)
    puts "#{Rails.env}: #{scope.count} carts eligible"
    next puts("DRY_RUN set; nothing deleted") if ENV["DRY_RUN"]

    deleted = 0
    scope.in_batches(of: 1_000) { |batch| deleted += batch.delete_all }
    puts "deleted #{deleted}"
  end
end
```

## Failure modes
Production task run against development/staging or vice versa, silent fallback behavior.

## Testing
Test allowed and rejected environments and missing prerequisites.

## Review checklist
[ ] environment explicit [ ] fail closed [ ] prerequisites [ ] no pre-side-effect work

## Related skills
rails-operational-tasks-maintenance, rails-production-runtime, rails-security-engineering