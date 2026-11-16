---
name: active-record-callback-contract
description: Use when adding or reviewing Active Record lifecycle callbacks, especially transactional callbacks.
family: rails
---

# Active Record Callback Contract

## Problem

Callbacks hide lifecycle order and can accidentally turn persistence into a workflow engine.

## Use when

- adding before/after save/create/update/destroy callbacks
- adding after_commit or after_rollback
- debugging callback order or side effects.

## Do not use when

- the behavior coordinates several independent domain steps
- a service/application workflow owns the operation.

## Repository inspection

Inspect callback order, validation lifecycle, transaction boundaries, inherited callbacks, and external side effects.

## Implementation procedure

1. State the lifecycle event that intrinsically owns the behavior.
2. Prefer deterministic, local callbacks.
3. Use after_commit when the effect depends on committed state.
4. Make retry/duplication behavior explicit for external effects.
5. Test callback scope and transaction outcome.
6. Extract workflows when responsibility crosses record boundaries.

## Example

```ruby
class Order < ApplicationRecord
  # Intrinsic to the record: normalize its own attribute.
  before_validation { self.email = email.to_s.strip.downcase }

  # External effect: only after the transaction commits, and idempotent
  # because the job keys on the order id.
  after_create_commit { OrderConfirmationJob.perform_later(id) }

  # Not here: charging cards, creating other aggregates, calling APIs in
  # before_save/after_save, where a rollback would leave them half-done.
end
```

## Failure modes

- network calls in before_save
- assuming after_save means committed
- duplicate after_commit effects without idempotency
- callback chains whose order is undocumented.

## Testing

Test callback invocation on success/failure and commit/rollback paths.

## Review checklist

- [ ] callback is record-local
- [ ] lifecycle phase is correct
- [ ] transaction semantics are explicit
- [ ] external side effects are safe
- [ ] tests cover failure paths

## Related skills

rails-active-record, rails-active-support, rails-database-engineering, rails-distributed-systems
