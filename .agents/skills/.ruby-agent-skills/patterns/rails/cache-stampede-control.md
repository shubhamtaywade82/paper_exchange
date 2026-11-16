---
name: cache-stampede-control
description: Control concurrent recomputation of expensive Rails cache values without introducing unnecessary distributed coordination.
family: rails
---

# Cache Stampede Control

## Problem

A popular cached value expires or is absent, causing many concurrent requests or jobs to recompute the same expensive value.

## Use when

Cache-miss contention is measured or a workload has a proven expensive concurrent recomputation path.

## Do not use when

There is no evidence of concurrent misses or the underlying computation is cheap enough that recomputation is preferable.

## Repository inspection

Inspect cache store, cache key/versioning, expiration policy, request/job concurrency, computation cost, multi-process topology, and existing cache coordination primitives.

## Implementation procedure

1. Measure miss rate and concurrent recomputation.
2. Define freshness/staleness requirements.
3. Prefer the simplest coordination mechanism that satisfies the contract.
4. Consider stale-while-revalidate or bounded recomputation before distributed locking.
5. Set a bounded lock/wait policy when coordination is required.
6. Define failure/recovery semantics.
7. Add hit/miss/concurrency tests.
8. Re-measure contention and latency.

## Example

```ruby
# race_condition_ttl lets one process recompute an expired entry while others
# briefly keep serving the old value instead of all recomputing at once.
Rails.cache.fetch("homepage/trending", expires_in: 5.minutes, race_condition_ttl: 10.seconds) do
  Trending.compute # ~2 s database aggregation
end
```

## Failure modes

- distributed lock added without measured contention
- indefinite lock waiting
- lock orphaning
- stale data violating authorization/tenant semantics
- cache key collisions
- serializing all traffic behind one hot key

## Testing

Test cache hit, miss, invalidation, concurrent miss behavior, timeout/failure behavior, and key isolation using the repository's cache/test conventions.

## Review checklist

- [ ] contention measured
- [ ] freshness contract explicit
- [ ] simplest mechanism chosen
- [ ] lock lifetime bounded when applicable
- [ ] failure behavior tested
- [ ] tenant/user identity preserved

## Related skills

- rails-performance
- rails-observability
- rails-security
- rails-test-engineering
- ruby-concurrency
