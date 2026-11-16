---
name: active-record-relation-composition
description: Use when building reusable, composable ActiveRecord::Relation logic.
family: rails
---

# Active Record Relation Composition

## Problem

Reusable query logic is often made less composable by returning arrays, embedding side effects, or hiding incompatible ordering/join assumptions.

## Use when

- composing model scopes
- creating query objects that return relations
- merging relation fragments.

## Do not use when

- the result is intentionally a materialized report/value list
- the query requires a workflow with external side effects.

## Repository inspection

Inspect existing scopes/query objects and their callers.

## Implementation procedure

1. Keep query-building methods relation-valued.
2. Compose with supported Relation APIs and merge where appropriate.
3. Avoid side effects during relation construction.
4. Document required joins/order/group preconditions.
5. Materialize only at the outer consumer boundary.

## Example

```ruby
class Invoice < ApplicationRecord
  scope :unpaid, -> { where(paid_at: nil) }
  scope :overdue, -> { unpaid.where(due_on: ...Date.current) }
  scope :for_account, ->(account) { where(account: account) }

  # Returns a Relation, not an Array, so callers can keep composing and
  # nothing hits the database until they enumerate.
  def self.reminder_candidates(account)
    for_account(account).overdue.where(reminded_at: nil)
  end
end

Invoice.reminder_candidates(account).order(:due_on).limit(100).find_each { |invoice| RemindJob.perform_later(invoice.id) }
```

## Failure modes

- hidden database calls during composition
- relation methods returning inconsistent types
- duplicate joins
- contradictory ordering or limit semantics.

## Testing

Test chainability, relation type, representative composition, and terminal result behavior.

## Review checklist

- [ ] relation remains composable
- [ ] no unexpected SQL
- [ ] preconditions are explicit
- [ ] terminal execution is intentional

## Related skills

rails-active-record, ruby-api-design, rails-performance
