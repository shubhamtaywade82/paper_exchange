---
name: task-namespace-contract
description: Task Namespace Contract
family: rails
---
# Task Namespace Contract

## Problem
Flat task names collide and make operational ownership unclear.

## Use when
Adding a custom Rake task.

## Do not use when
A one-off local command that will never be committed.

## Repository inspection
Inspect existing task namespaces and naming conventions.

## Implementation procedure
Choose a namespace based on operational responsibility and use explicit action names.

## Example

```ruby
# lib/tasks/billing.rake — namespace = owning domain; name = action.
namespace :billing do
  namespace :invoices do
    desc "Generate invoices for the previous month (owner: billing team)"
    task generate: :environment do
      Billing::GenerateInvoices.call(period: Date.current.prev_month)
    end

    desc "Resend failed invoice emails (owner: billing team)"
    task resend_failed: :environment do
      Billing::Invoice.email_failed.find_each { InvoiceMailer.issued(_1).deliver_later }
    end
  end
end
# bin/rails -T billing  lists everything the billing team owns.
```

## Failure modes
Collisions, ambiguous task ownership, broken automation references.

## Testing
Assert the task name exists and invokes the intended workflow.

## Review checklist
[ ] namespace [ ] action name [ ] existing collision checked

## Related skills
rails-operational-tasks-maintenance