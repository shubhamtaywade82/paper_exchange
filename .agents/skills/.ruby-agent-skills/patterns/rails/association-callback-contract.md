---
name: association-callback-contract
description: Use when adding before_add, after_add, before_remove, or after_remove callbacks to a collection association.
family: rails
---

# Association Callback Contract

## Problem

Association callbacks can hide mutation-time business rules and side effects behind collection operations.

## Use when

- adding association callbacks
- debugging collection mutation
- enforcing local collection limits.

## Do not use when

- the workflow spans multiple aggregates or external systems.

## Repository inspection

Inspect collection mutation methods, callback order, abort behavior, transactions, and tests.

## Implementation procedure

1. Identify the collection mutation the callback owns.
2. Keep the callback local and deterministic.
3. Define abort/halting behavior.
4. Avoid network or durable workflow side effects.
5. Test add/remove through the actual association API.

## Example

```ruby
class Team < ApplicationRecord
  has_many :memberships
  # Narrow and deterministic: guard the collection's own invariant only.
  has_many :members, through: :memberships, source: :user, before_add: :enforce_seat_limit

  private

  def enforce_seat_limit(_user)
    raise ActiveRecord::RecordInvalid, self if members.size >= seat_limit
  end
end
# Invitations, billing seat changes, and emails belong to Teams::AddMember,
# not to after_add.
```

## Failure modes

- external I/O in association callbacks
- assuming callbacks run for direct bulk SQL
- callback order hidden from callers
- authorization embedded in callback mutation.

## Testing

Test successful add/remove, aborted mutation, and unaffected mutation paths.

## Review checklist

- [ ] callback owns association-local behavior
- [ ] abort semantics are explicit
- [ ] no external workflow is hidden
- [ ] tests use actual collection operations

## Related skills

rails-associations, rails-active-record, rails-security
