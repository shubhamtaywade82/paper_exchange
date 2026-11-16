---
name: association-loading-contract
description: Use when an association traversal path must have deliberate loading, inverse, or strict-loading behavior.
family: rails
---

# Association Loading Contract

## Problem

Association access can produce N+1 queries, duplicate object instances, or unnecessary graph materialization when loading strategy and inverse behavior are implicit.

## Use when

- reviewing association traversal
- introducing includes/preload/eager_load/strict_loading
- debugging duplicate queries around parent/child traversal.

## Do not use when

- the task has no relationship traversal or loading behavior.

## Repository inspection

Inspect the actual consumer path, association cardinality, inverse_of, existing preload strategy, and query/performance tests.

## Implementation procedure

1. Identify the exact traversal.
2. Check whether inverse recognition already prevents repeated loads.
3. Choose the narrowest preload/eager-load strategy.
4. Use strict loading when accidental lazy loading should be prohibited.
5. Measure query count and result cardinality.

## Example

```ruby
# The view traverses order -> customer and order -> line_items -> product;
# load exactly that graph for exactly this page.
@orders = current_account.orders
  .includes(:customer, line_items: :product)
  .order(created_at: :desc)
  .limit(25)

# Filtering on an association needs a JOIN; preloading it is separate.
Order.joins(:customer).where(customers: { country: "IN" }).preload(:line_items)
```

## Failure modes

- global eager loading
- ignoring inverse_of and fixing only the symptom
- strict_loading disabled globally after one failure
- loading large child collections into memory unnecessarily.

## Testing

Test representative traversal with expected query/load behavior and strict-loading failures where applicable.

## Review checklist

- [ ] traversal path is known
- [ ] inverse behavior is reviewed
- [ ] loading strategy is narrow
- [ ] query behavior is evidenced

## Related skills

rails-associations, rails-active-record, rails-performance, rails-test-engineering
