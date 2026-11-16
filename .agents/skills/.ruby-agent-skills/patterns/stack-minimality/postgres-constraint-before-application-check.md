---
name: postgres-constraint-before-application-check
description: PostgreSQL Constraint Before Application Check
family: stack-minimality
---
# PostgreSQL Constraint Before Application Check

## Problem
Application validation alone can be bypassed by races, other writers, or direct SQL.

## Use when
Designing uniqueness, referential integrity, allowed-state, or other durable invariants.

## Do not use when
The rule is intentionally advisory or cannot be represented safely in the database.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Inspect schema, migrations, constraints, write paths, and deployment order. Keep useful user-facing validation while making PostgreSQL enforce the durable invariant.

## Example

```ruby
class AddUniqueEmailPerTenant < ActiveRecord::Migration[8.0]
  def change
    add_index :users, [:tenant_id, :email], unique: true
    add_check_constraint :orders, "quantity > 0", name: "orders_quantity_positive"
  end
end

class User < ApplicationRecord
  # Friendly error message; the index above is what actually holds under races.
  validates :email, uniqueness: { scope: :tenant_id }
end
```

## Failure modes
Validation-only uniqueness and foreign-key conventions without actual constraints.

## Testing
Test application errors and database enforcement when database enforcement is part of the contract.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
rails-validations, rails-database-engineering, stack-minimality
