---
name: active-record-strict-loading
description: Use when preventing accidental lazy loading and making N+1 behavior an explicit Active Record contract.
family: rails
---

# Active Record Strict Loading

## Problem

Association lazy loading can hide N+1 queries until production or a large test suite exposes them.

## Use when

- reviewing N+1 behavior
- adding strict_loading
- hardening a known rendering/query boundary.

## Do not use when

- association access is intentionally lazy and the workload is proven bounded.

## Repository inspection

Inspect query consumers, association access, test helpers, and existing eager-loading conventions.

## Implementation procedure

1. Identify the query path that must not issue lazy loads.
2. Choose preloading or strict_loading deliberately.
3. Keep the object graph narrow.
4. Add tests that fail on prohibited lazy access where practical.
5. Measure the resulting query count/cost.

## Example

```ruby
class Order < ApplicationRecord
  has_many :line_items, strict_loading: true
end

# config/environments/development.rb and test.rb:
#   config.active_record.strict_loading_by_default = true
#   config.active_record.action_on_strict_loading_violation = :raise

orders = Order.includes(:line_items).where(account: account).to_a
orders.each { |order| order.line_items.sum(&:amount_cents) } # preloaded: fine

Order.first.line_items.to_a # raises ActiveRecord::StrictLoadingViolationError
```

## Failure modes

- enabling strict loading globally without migration strategy
- disabling strict loading to silence regressions
- preloading unrelated graphs.

## Testing

Exercise the consumer path and assert the intended preload/strict-loading behavior.

## Review checklist

- [ ] target path is known
- [ ] preload graph is narrow
- [ ] strict-loading failure is actionable
- [ ] query evidence exists

## Related skills

rails-active-record, rails-performance, rails-test-engineering
