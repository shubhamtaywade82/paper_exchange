---
name: validation-boundary
description: Use when deciding where a Rails invariant should be enforced across model validation and database integrity.
family: rails
---

# Validation Boundary Contract

## Problem
Validation Boundary Contract needs an explicit contract so validation does not drift between model logic, database integrity, and consumers.

## Use when
- a rule could live in a model, controller, service, or database;
- a change risks duplicating one invariant across layers.

## Do not use when
- the real boundary is authorization, transaction orchestration, or external integration;
- the database already owns an authoritative invariant.

## Repository inspection
- model/object;
- schema constraints and indexes;
- request/form/API boundary;
- service/job/event entry points;
- existing tests.

## Implementation procedure
1. State the invariant in domain terms.
2. Identify who must enforce it under concurrency and alternate writers.
3. Keep user-facing model validation where appropriate.
4. Add database constraints for authoritative cross-writer invariants.
5. Remove conflicting duplicate rules.
6. Test every reachable enforcement boundary.

## Example

```ruby
class Coupon < ApplicationRecord
  # Model validation: is this state acceptable for user-facing writes?
  validates :code, presence: true, format: { with: /\A[A-Z0-9]{6,12}\z/ }
  validates :percent_off, numericality: { in: 1..90 }
  validates :code, uniqueness: { case_sensitive: false }
end

# Database: the invariants that must survive every writer and concurrency.
class CreateCoupons < ActiveRecord::Migration[8.0]
  def change
    create_table :coupons do |t|
      t.string :code, null: false
      t.integer :percent_off, null: false
      t.check_constraint "percent_off BETWEEN 1 AND 90", name: "coupons_percent_off_range"
      t.index "lower(code)", unique: true
    end
  end
end
# Not validation's job: whether this user may create coupons (policy).
```

## Failure modes
- validation becomes authorization;
- validation disagrees with database semantics;
- alternate writers bypass the only protection.

## Testing
- valid and invalid model state;
- database conflict behavior;
- bypass writer behavior where relevant.

## Review checklist
- [ ] invariant owner is named
- [ ] database enforcement is evaluated
- [ ] authorization is separate
- [ ] alternate writers are considered

## Related skills
- rails-validations
- rails-active-record
- rails-database-engineering
- rails-test-engineering
