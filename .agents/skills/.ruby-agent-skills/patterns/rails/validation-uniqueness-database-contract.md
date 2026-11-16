---
name: validation-uniqueness-database-contract
description: Use when combining Rails uniqueness validation with authoritative database uniqueness enforcement.
family: rails
---

# Validation Uniqueness Database Contract

## Problem
Validation Uniqueness Database Contract needs an explicit contract so validation does not drift between model logic, database integrity, and consumers.

## Use when
- a value or composite key must remain unique across concurrent writers.

## Do not use when
- application validation is being treated as the sole enforcement mechanism.

## Repository inspection
- uniqueness validator;
- scope/case/conditions;
- normalization;
- existing indexes/constraints;
- tenant key;
- conflict handling.

## Implementation procedure
1. Define the logical uniqueness key.
2. Align application and persisted representations.
3. Add or verify the unique index/constraint.
4. Define application behavior for the database conflict.
5. Test sequential and conflict cases.

## Example

```ruby
class Membership < ApplicationRecord
  # Friendly error in the common case...
  validates :user_id, uniqueness: { scope: :team_id }
end

# ...and the real guarantee under concurrency.
class AddUniqueIndexToMemberships < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :memberships, %i[team_id user_id], unique: true, algorithm: :concurrently
  end
end

# Race loser gets RecordNotUnique; map it to the same user-facing error.
def join!(team, user)
  Membership.create!(team:, user:)
rescue ActiveRecord::RecordNotUnique
  Membership.find_by!(team:, user:) # idempotent join
end
```

## Failure modes
- scope mismatch;
- case/collation mismatch;
- tenant key omitted;
- race condition remains.

## Testing
- duplicate create;
- scoped/tenant uniqueness;
- case/normalization;
- database conflict.

## Review checklist
- [ ] validator is feedback
- [ ] database constraint is authoritative
- [ ] scope and normalization agree

## Related skills
- rails-validations
- rails-active-record
- rails-database-engineering
- rails-test-engineering
