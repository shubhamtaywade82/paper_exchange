---
name: validation-associated-graph
description: Use when validating owned Active Record associations without creating an unbounded validation graph.
family: rails
---

# Associated Validation Graph Contract

## Problem
Associated Validation Graph Contract needs an explicit contract so validation does not drift between model logic, database integrity, and consumers.

## Use when
- associated records must be valid as part of an owned write.

## Do not use when
- the parent should not recursively validate an unbounded graph;
- unrelated associations are not part of the contract.

## Repository inspection
- association declarations;
- inverse/autosave/nested attributes;
- graph size;
- transaction behavior.

## Implementation procedure
1. Identify exact owned associated records.
2. Keep the graph narrow.
3. Coordinate inverse/autosave semantics.
4. Define parent failure behavior.
5. Avoid duplicate validation passes.
6. Test success and failure.

## Example

```ruby
class Order < ApplicationRecord
  has_many :line_items, inverse_of: :order, dependent: :destroy
  accepts_nested_attributes_for :line_items, allow_destroy: true, limit: 100

  # has_many validates new/changed children on save by default (autosave for new records);
  # the limit bounds the graph.
  validates :line_items, length: { minimum: 1, message: :blank }
end

class LineItem < ApplicationRecord
  belongs_to :order, inverse_of: :line_items # presence check uses the in-memory parent
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
end

order = Order.new(line_items_attributes: [{ quantity: 0 }])
order.valid? # => false; order.errors[:"line_items.quantity"] => ["must be greater than 0"]
```

## Failure modes
- recursive validation loops;
- unrelated children block saves;
- partial persistence is misunderstood.

## Testing
- parent/child valid;
- child invalid;
- multiple failures;
- nested/autosave rollback behavior.

## Review checklist
- [ ] graph is bounded
- [ ] ownership is explicit
- [ ] failure propagation is tested

## Related skills
- rails-validations
- rails-active-record
- rails-database-engineering
- rails-test-engineering
