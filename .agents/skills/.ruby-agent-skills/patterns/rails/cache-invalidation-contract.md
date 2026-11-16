---
name: cache-invalidation-contract
description: Tie cache freshness and invalidation to the authoritative domain state transition instead of scattered callers.
family: rails
---

# Cache Invalidation Contract

## Problem

A cache remains stale because invalidation is attached to one caller rather than the authoritative state change that affects the cached value.

## Use when

- a cached value depends on mutable domain state;
- multiple writers can change the source data;
- TTL alone cannot guarantee acceptable freshness.

## Do not use when

- the value is immutable;
- versioned keys already make stale entries unreachable and that contract is sufficient;
- the repository already has one authoritative invalidation mechanism.

## Repository inspection

Inspect models/domain services, all write paths, transactions, callbacks, jobs, events, cache dependencies, and existing invalidation helpers.

## Implementation procedure

1. Identify the source-of-truth state.
2. Enumerate all mutations that change cached semantics.
3. Choose the owning state-transition boundary.
4. Define whether invalidation happens before, after, or atomically with the change.
5. Define behavior on partial failure.
6. Test each mutation path.
7. Observe invalidation lag/failure where operationally relevant.

## Example

```ruby
class Price < ApplicationRecord
  belongs_to :product, touch: true # the authoritative change bumps product.updated_at
end

class Product < ApplicationRecord
  has_many :prices

  # Keyed on the record version, so every write path that changes prices
  # (admin, import, API) invalidates it without remembering to delete keys.
  def price_table
    Rails.cache.fetch([self, "price_table"]) { prices.order(:currency).pluck(:currency, :amount_cents) }
  end
end
```

## Failure modes

- controller-only invalidation;
- missing alternate writer;
- invalidation before rollback-safe persistence;
- stale cache after background job update;
- invalidation failure hidden by successful write;
- broad cache flush masking missing dependency modeling.

## Testing

Cover every write path that changes the cached value and verify stale entries are no longer served beyond the defined contract.

## Review checklist

- [ ] authoritative state owner identified
- [ ] all material writers considered
- [ ] transaction timing explicit
- [ ] partial failure behavior explicit
- [ ] deterministic invalidation tests

## Related skills

rails-caching, rails-database-engineering, rails-active-job, rails-event-driven-messaging, rails-distributed-systems
