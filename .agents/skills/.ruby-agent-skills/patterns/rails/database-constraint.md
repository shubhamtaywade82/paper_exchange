---
name: database-constraint
description: Enforce a cross-writer data invariant at the database boundary.
family: rails
---

# Database Constraint

## Problem
Application validations alone can race when multiple writers modify the same data concurrently.

## Use when
An invariant must hold regardless of which process or application path writes the database.

## Do not use when
The rule is contextual presentation logic that cannot be represented as a durable database invariant.

## Implementation procedure
1. State the invariant precisely.
2. Add application validation for useful error feedback.
3. Add the corresponding unique, foreign-key, check, or NOT NULL database constraint.
4. Audit existing data before enabling the constraint.
5. Handle database constraint violations at the application boundary.
6. Test duplicate/concurrent writes where relevant.

## Example

```ruby
class AddExternalReferenceUniqueness < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # The race-safe guarantee: two concurrent inserts cannot both succeed.
    add_index :orders, [:tenant_id, :external_reference], unique: true, algorithm: :concurrently
  end
end

class Order < ApplicationRecord
  # Friendly message for the common case; the index handles the race.
  validates :external_reference, uniqueness: { scope: :tenant_id }
end

begin
  Order.create!(tenant_id: 1, external_reference: "PO-7")
rescue ActiveRecord::RecordNotUnique
  # concurrent duplicate lost the race: report it as a validation error
end
```

## Failure modes
- relying on model uniqueness validation alone
- adding a constraint before cleaning violating rows
- swallowing constraint violations as generic success

## Testing
Test valid application behavior and direct database rejection of invalid state.

## Review checklist
- invariant is explicit
- DB constraint is authoritative
- existing data is clean
- violation behavior is understood


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
