---
name: transaction-boundary
description: Use when multiple database changes must succeed or fail together and the atomicity boundary needs to be explicit.
family: rails
---

# Transaction Boundary

## Problem

A workflow changes multiple persistent records and partial success would leave invalid application state.

## Use when

- multiple database writes form one atomic operation
- invariants span records
- partial completion is unacceptable

## Do not use when

- writes are independent
- an external API call is incorrectly assumed to be transactional with the database

## Repository inspection

Inspect existing transaction conventions, callbacks, locks, database constraints, external side effects, and failure handling.

## Structure

~~~ruby
ApplicationRecord.transaction do
  order.update!(status: "paid")
  payment.update!(order: order)
end
~~~

The exact boundary must match the domain operation.

## Implementation procedure

1. Identify the invariant that requires atomicity.
2. List every database write participating in it.
3. Define the smallest transaction boundary.
4. Keep external side effects outside the transaction when they cannot participate atomically.
5. Decide retry/idempotency behavior where relevant.
6. Test rollback behavior.

## Failure modes

- transactions around unrelated work
- long-running external calls inside transactions
- assuming transaction rollback undoes emails/API calls
- missing database constraints for concurrent writes
- swallowing exceptions that should trigger rollback

## Testing

Test successful completion and failure after an intermediate write. Verify the database state is rolled back as expected.

## Review checklist

- [ ] atomicity requirement is explicit
- [ ] transaction scope is minimal
- [ ] external side effects considered
- [ ] concurrency/constraints considered
- [ ] rollback tested

## Related skills

- rails-active-record
- rails-validations
- rails-test-engineering
- ruby-tdd-refactoring
