---
name: active-record-query-contract
description: Use when an Active Record query must preserve relation shape, cardinality, ordering, and laziness/materialization semantics.
family: rails
---

# Active Record Query Contract

## Problem

Query refactors can silently change result type, cardinality, ordering, SQL timing, or downstream composability.

## Use when

- changing where/select/join/order/group/limit logic
- introducing pluck/pick/existence checks
- refactoring a query object or scope.

## Do not use when

- the task does not change a query contract.

## Repository inspection

Inspect callers, current SQL/query tests, expected result type, ordering requirements, and database constraints.

## Implementation procedure

1. State the returned type: Relation, model collection, scalar, or aggregate.
2. State ordering and uniqueness requirements.
3. Identify when SQL is intentionally executed.
4. Preserve composability when callers need further scopes.
5. Review joins for cardinality changes.
6. Test empty, duplicate, and boundary cases.

## Example

```ruby
class Order < ApplicationRecord
  # Contract: returns a Relation (composable), ordered deterministically,
  # one row per order even though it joins line items.
  def self.containing_sku(sku)
    where(id: LineItem.where(sku: sku).select(:order_id)).order(created_at: :desc, id: :desc)
  end
end

Order.containing_sku("A1").where(account: current_account).limit(20) # still composes
```

## Failure modes

- Relation unexpectedly becoming Array
- pluck replacing model objects
- joins creating duplicate rows
- implicit ordering assumed
- query executed earlier than callers expect.

## Testing

Test result shape, ordering, cardinality, composition, and representative query execution.

## Review checklist

- [ ] result type explicit
- [ ] cardinality preserved
- [ ] ordering explicit
- [ ] execution/materialization understood
- [ ] callers remain compatible

## Related skills

rails-active-record, rails-performance, rails-database-engineering
