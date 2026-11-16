---
name: activejob-argument-serialization-contract
description: Active Job Argument Serialization Contract
family: rails
---
# Active Job Argument Serialization Contract

## Problem
Job arguments fail later when queue persistence cannot represent them or when payloads depend on process-local state.

## Use when
Changing job argument types or payload shape.

## Do not use when
A job only accepts documented primitive/container types and no custom serializer is needed.

## Repository inspection
Inspect supported argument types, GlobalID usage, custom serializers, queue adapter, payload limits, and deserialization behavior.

## Implementation procedure
Prefer simple immutable arguments or GlobalID-backed records; keep payloads small and stable across deploys.

## Example

```ruby
# Arguments are small and serializable: a Global ID for the record, plain
# values for the rest. No lambdas, IO, request objects, or large hashes.
class InvoiceReminderJob < ApplicationJob
  def perform(invoice, reminder_kind, sent_by_id)
    return unless invoice.unpaid? # re-read state at execution time

    InvoiceMailer.with(invoice:, kind: reminder_kind, sent_by: User.find(sent_by_id)).reminder.deliver_now
  end
end

InvoiceReminderJob.perform_later(invoice, "second_notice", current_user.id)
# Serialized as: [{"_aj_globalid"=>"gid://app/Invoice/42"}, "second_notice", 7]
```

## Failure modes
Serialization errors, oversized payloads, version skew, mutable-state bugs.

## Testing
Assert enqueued arguments and execute serialization/deserialization round trips.

## Review checklist
[ ] supported types [ ] payload size [ ] deploy compatibility [ ] round trip

## Related skills
rails-serialization-globalid-engineering, rails-active-job