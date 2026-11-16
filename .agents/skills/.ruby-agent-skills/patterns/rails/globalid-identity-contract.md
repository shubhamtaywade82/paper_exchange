---
name: globalid-identity-contract
description: Global ID Identity Contract
family: rails
---
# Global ID Identity Contract

## Problem
Queues and cross-process workflows become brittle when mutable model state is serialized instead of an identity reference.

## Use when
Passing model instances to Active Job or referencing models across process boundaries.

## Do not use when
A snapshot of immutable state is deliberately required.

## Repository inspection
Inspect job arguments, model lifecycle, GlobalID support, retry semantics, and consumer timing.

## Implementation procedure
Use Global ID for live model identity; fetch current state at execution time and define behavior when the record disappears.

## Example

```ruby
# Active Job serializes the record as a GlobalID and reloads it at perform time.
class SendReceiptJob < ApplicationJob
  discard_on ActiveJob::DeserializationError # the order was deleted before we ran

  def perform(order)
    OrderMailer.receipt(order).deliver_now # current state, not the enqueue-time snapshot
  end
end

SendReceiptJob.perform_later(order) # payload: {"_aj_globalid"=>"gid://shop/Order/42"}

# Wrong: freezes mutable state into the queue and leaks attributes.
# SendReceiptJob.perform_later(order.attributes)
```

## Failure modes
Stale snapshots, oversized jobs, object graph serialization, deleted-record failures.

## Testing
Test enqueue/dequeue round trips and deleted-record behavior.

## Review checklist
[ ] identity vs snapshot [ ] current-state semantics [ ] missing record policy

## Related skills
rails-serialization-globalid-engineering, rails-active-job