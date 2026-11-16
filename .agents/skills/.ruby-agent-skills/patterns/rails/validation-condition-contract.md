---
name: validation-condition-contract
description: Use when implementing conditional Rails validations with explicit if, unless, nil, or blank semantics.
family: rails
---

# Conditional Validation Contract

## Problem
Conditional Validation Contract needs an explicit contract so validation does not drift between model logic, database integrity, and consumers.

## Use when
- a validation is valid only for a clear predicate.

## Do not use when
- the predicate is a workflow or authorization decision;
- interacting if/unless branches make the model unreadable.

## Repository inspection
- predicate methods;
- state attributes;
- if/unless/allow_nil/allow_blank;
- context interaction;
- truth-table tests.

## Implementation procedure
1. Use a named predicate for non-trivial conditions.
2. Separate conditions from permissions.
3. Define nil/blank behavior independently.
4. Test all branches and boundary transitions.

## Example

```ruby
class Shipment < ApplicationRecord
  enum :method, { courier: "courier", pickup: "pickup" }

  validates :address, presence: true, if: :courier?
  validates :pickup_point_id, presence: true, if: :pickup?
  validates :tracking_number, presence: true, if: -> { courier? && dispatched_at.present? }
  validates :notes, length: { maximum: 500 }, allow_blank: true
end

# test covers each branch:
#   Shipment.new(method: :pickup).errors_on(:address) is empty
#   Shipment.new(method: :courier, dispatched_at: Time.current) requires tracking_number
```

## Failure modes
- validation silently disappears because a predicate changed;
- blank/nil skips more rules than intended;
- condition encodes authorization.

## Testing
- every condition branch;
- nil/blank;
- create/update/context combinations.

## Review checklist
- [ ] predicate is focused
- [ ] truth table is covered
- [ ] nil/blank semantics are intentional

## Related skills
- rails-validations
- rails-active-record
- rails-database-engineering
- rails-test-engineering
