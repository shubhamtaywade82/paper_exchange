---
name: through-association-contract
description: Use when designing or changing has_many through or has_one through relationships and join-model lifecycle.
family: rails
---

# Through Association Contract

## Problem

Through associations combine multiple relationship declarations and can hide join creation, deletion, cardinality, and domain ownership.

## Use when

- adding or changing has_many through
- changing join models
- changing assignment or collection mutation through a join.

## Do not use when

- the join is purely a query concern with no association contract.

## Repository inspection

Inspect source association, join model, target association, validations, uniqueness, foreign keys, callbacks, and authorization.

## Implementation procedure

1. Define the source, join, and target cardinalities.
2. Decide whether the join model is the domain owner of relationship state.
3. Use source/source_type/class_name explicitly when needed.
4. Test creation/removal/assignment semantics.
5. Verify that deleting join records does not accidentally imply deleting targets.

## Example

```ruby
class Project < ApplicationRecord
  has_many :memberships, dependent: :destroy        # the join model is the contract
  has_many :members, through: :memberships, source: :user
end

class Membership < ApplicationRecord
  belongs_to :project
  belongs_to :user
  validates :role, inclusion: { in: %w[viewer editor admin] }
  validates :user_id, uniqueness: { scope: :project_id } # + unique index [project_id, user_id]
end

# Adding through the join model makes role explicit:
project.memberships.create!(user:, role: "editor")
# Removing a member deletes the Membership row, never the User:
project.memberships.find_by!(user:).destroy!
```

## Failure modes

- HABTM for a behavior-rich join
- assuming through deletion destroys target records
- missing uniqueness on join pairs
- ambiguous source association.

## Testing

Test join creation, replacement, removal, duplicate prevention, target preservation, and authorization.

## Review checklist

- [ ] join ownership is explicit
- [ ] cardinality is correct
- [ ] mutations are understood
- [ ] target lifecycle is separate from join lifecycle

## Related skills

rails-associations, rails-active-record, rails-database-engineering, rails-security
