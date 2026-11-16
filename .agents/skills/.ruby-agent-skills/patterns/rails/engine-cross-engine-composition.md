---
name: engine-cross-engine-composition
description: Engine Cross-Composition Contract
family: rails
---
# Engine Cross-Composition Contract

## Problem
Multiple engines can accidentally depend on load order, shared globals, or private implementation details.

## Use when
Adding or changing dependencies between engines.

## Do not use when
A single engine has no other engine dependency.

## Repository inspection
Inspect dependency graph, namespaces, initializers, routes, configuration, and shared contracts.

## Implementation procedure
Expose stable interfaces, avoid private constant coupling, and make required initialization order explicit.

## Example

```ruby
# Engines talk through public APIs and events, not each other's models or
# load order.
module Shipping
  def self.quote(order_id:, items:) = Quote.for(items) # public API
end

module Checkout
  class Totals
    def call(order)
      shipping = Shipping.quote(order_id: order.id, items: order.items.map(&:sku))
      ActiveSupport::Notifications.instrument("checkout.totals_computed", order_id: order.id)
      order.subtotal_cents + shipping.cents
    end
  end
end
# Not: Shipping::Rate.where(...) from inside Checkout.
```

## Failure modes
Circular dependencies, load-order bugs, namespace collisions, cascading upgrades.

## Testing
Test participating engines in host composition and verify boot/load order.

## Review checklist
[ ] dependency graph [ ] public interface [ ] no private coupling [ ] composition test

## Related skills
rails-engines-railties-engineering, rails-initialization-configuration-engineering, rails-zeitwerk