---
name: nested-serialization-boundary
description: Nested Serialization Boundary
family: rails
---
# Nested Serialization Boundary

## Problem
Nested associations can create oversized or recursively expanding payloads and hidden queries.

## Use when
Adding nested association serialization.

## Do not use when
A flat representation with no association traversal.

## Repository inspection
Inspect association cardinality, preload strategy, recursive relations, response size, and query count.

## Implementation procedure
Define bounded nesting, explicit fields, preloads, and collection limits where applicable.

## Example

```ruby
class OrdersController < ApplicationController
  def index
    orders = Current.account.orders.includes(line_items: :product).order(id: :desc).limit(50)
    render json: orders.map { |order| order_json(order) }
  end

  private

  # One level of nesting, explicit fields, bounded collection.
  def order_json(order)
    {
      id: order.id,
      total_cents: order.total_cents,
      line_items: order.line_items.map do |item|
        { product_id: item.product_id, name: item.product.name, quantity: item.quantity }
      end
    }
  end
end
# Not: render json: orders, include: { line_items: { include: :product } }  (every column, every level)
```

## Failure modes
N+1 queries, recursive output, payload explosions, latency regressions.

## Testing
Use serializer/request tests with query-count and representative payload assertions.

## Review checklist
[ ] cardinality [ ] preload [ ] recursion [ ] payload size

## Related skills
rails-serialization-globalid-engineering, rails-performance