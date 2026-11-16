---
name: transaction-lock-boundary
description: Define a minimal database transaction and lock boundary for a concurrency-sensitive state transition.
family: rails
---

# Transaction Lock Boundary

## Problem
Concurrent writers can observe and modify the same state unless the invariant is protected.

## Use when
A state transition depends on persisted state and concurrent updates must be serialized.

## Do not use when
A database constraint or atomic update already expresses and enforces the invariant.

## Implementation procedure
1. State the invariant.
2. Identify the rows that own the state.
3. Choose atomic SQL, unique constraint, optimistic locking, or pessimistic locking.
4. If locking is needed, acquire it as late as practical.
5. Keep the protected transaction section short.
6. Establish consistent lock ordering.
7. Define deadlock/retry semantics.

## Example

```ruby
class Wallet < ApplicationRecord
  InsufficientFunds = Class.new(StandardError)

  # Invariant: balance never goes negative, even under concurrent debits.
  def debit!(amount_cents, reference:)
    with_lock do # SELECT ... FOR UPDATE; the check and the write see the same row version
      raise InsufficientFunds if balance_cents < amount_cents

      update!(balance_cents: balance_cents - amount_cents)
      entries.create!(amount_cents: -amount_cents, reference:)
    end
  end
end
# Belt and braces: CHECK (balance_cents >= 0) and a unique index on entries.reference.
```

## Failure modes
- locking unrelated rows
- holding locks during network calls
- inconsistent lock ordering
- lock used where a database constraint would be stronger

## Testing
Exercise conflicting transactions where practical.

## Review checklist
- invariant is explicit
- smallest row set is locked
- transaction duration is bounded
- retry is safe
- constraint alternative considered


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
