---
name: active-record-before-repository
description: Active Record Before Repository
family: stack-minimality
---
# Active Record Before Repository

## Problem
A pass-through repository around Active Record adds indirection without changing ownership.

## Use when
Evaluating repositories or extracting persistence code.

## Do not use when
Persistence is genuinely multi-source, independently owned, or protected by a stable persistence contract.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Inspect models, scopes, query objects, adapters, and all callers. Keep ordinary reads and writes in Active Record; extract only a real persistence boundary.

## Example

```ruby
# Before: a repository that only forwards to Active Record.
class OrderRepository
  def find_open_for(customer) = Order.where(customer: customer, status: "open").to_a
end
OrderRepository.new.find_open_for(customer)

# After: a named scope on the model that already owns the query.
class Order < ApplicationRecord
  scope :open_for, ->(customer) { where(customer: customer, status: "open") }
end
Order.open_for(customer)
```

## Failure modes
Pass-through repositories, duplicated Active Record APIs, mock-heavy persistence tests.

## Testing
Prefer integration coverage against the real test database for persistence semantics.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
rails-active-record, ruby-domain-modeling, rails-database-engineering, stack-minimality
