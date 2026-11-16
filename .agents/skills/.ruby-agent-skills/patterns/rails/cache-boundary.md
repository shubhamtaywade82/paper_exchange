---
name: cache-boundary
description: Introduce or review a Ruby/Rails cache with explicit key, freshness, invalidation, capacity, and failure semantics.
family: rails-quality
---

# Cache Boundary

## Problem

A computation or response is expensive enough to cache, but caching changes freshness and correctness semantics.

## Use when

Use for fragment caching, low-level caching, API response caching, or computed-value caching.

## Do not use when

Do not use when a measured query, index, algorithm, or representation fix addresses the bottleneck without introducing stale state.

## Implementation procedure

1. Measure the expensive operation.
2. Define freshness requirements.
3. Define cache key and version.
4. Define invalidation/dependency behavior.
5. Define miss/stampede behavior.
6. Estimate storage and serialization cost.
7. Verify multi-process/distributed behavior.
8. Add cache hit/miss/invalidation tests.
9. Measure after introducing the cache.

## Example

```ruby
class Product < ApplicationRecord
  # Cached value: the public price list for one product; freshness comes from
  # the record version in the key, so an update is visible immediately.
  def public_price_breakdown
    Rails.cache.fetch([self, "price_breakdown", "v2"], expires_in: 12.hours) do
      PriceCalculator.new(self).breakdown # ~200 ms, same for every viewer
    end
  end
end
# Not cached: anything that depends on the viewer (discounts, permissions).
```

## Failure modes

- stale authorization-sensitive data
- cache keys missing tenant/user identity
- unbounded cache growth
- cache stampede
- invalidation not matching data changes
- caching errors as successful values
- serialization cost exceeding saved computation

## Testing

Test hit, miss, invalidation, key isolation, and stale-data behavior.

## Related skills

- ruby-performance
- rails-active-record
- rails-authentication
- rails-test-engineering
- rails-security


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.
## Review checklist

- [ ] key includes every correctness/security identity dimension
- [ ] freshness/invalidation contract is explicit
- [ ] miss/stampede behavior is understood
- [ ] storage/serialization cost is acceptable
