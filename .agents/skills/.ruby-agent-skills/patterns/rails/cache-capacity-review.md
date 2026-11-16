---
name: cache-capacity-review
description: Review cache storage, value size, TTL, eviction, hot keys, and serialization as a finite capacity system.
family: rails
---

# Cache Capacity Review

## Problem

Cache hit-rate optimization can hide memory, network, serialization, eviction, and hot-key costs.

## Use when

- cache size or eviction behavior is changing;
- large values or high-cardinality keys are introduced;
- hit rate looks good while latency or resource usage worsens.

## Do not use when

- cache usage is trivial and capacity is not a meaningful constraint.

## Repository inspection

Inspect cache-store limits, value size distribution, TTLs, eviction policy, key cardinality, serialization format, network latency, namespaces, and process/region topology.

## Implementation procedure

1. Estimate item count and value size.
2. Inspect TTL distribution.
3. Identify hot keys and high-cardinality namespaces.
4. Measure serialization/network overhead.
5. Determine eviction behavior.
6. Set bounded growth expectations.
7. Add operational signals.

## Example

```bash
# Before raising TTLs or adding keys, look at what the cache is actually doing.
redis-cli -u "$REDIS_CACHE_URL" INFO stats   | grep -E "keyspace_(hits|misses)|evicted_keys"
redis-cli -u "$REDIS_CACHE_URL" INFO memory  | grep -E "used_memory_human|maxmemory_human|maxmemory_policy"
redis-cli -u "$REDIS_CACHE_URL" --bigkeys    # oversized serialized values
redis-cli -u "$REDIS_CACHE_URL" --hotkeys    # requires an LFU eviction policy
```

## Failure modes

- unbounded namespace growth;
- large values causing network/serialization overhead;
- hot-key contention;
- short TTL increasing misses;
- long TTL retaining obsolete data;
- eviction causing load spikes.

## Testing

Use representative value sizes and cardinalities where practical; verify key growth and behavior under eviction/failure.

## Review checklist

- [ ] capacity model
- [ ] value size
- [ ] cardinality
- [ ] TTL
- [ ] eviction
- [ ] hot-key behavior
- [ ] operational visibility

## Related skills

rails-caching, rails-performance, ruby-performance, rails-observability
