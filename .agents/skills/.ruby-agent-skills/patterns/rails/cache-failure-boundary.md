---
name: cache-failure-boundary
description: Define safe behavior when a Rails cache store is unavailable, slow, inconsistent, or returning invalid data.
family: rails
---

# Cache Failure Boundary

## Problem

Cache outages can become application outages when cache access is treated as an unconditional dependency or when failure fallback creates unbounded source load.

## Use when

- the cache store is shared infrastructure;
- cache availability can affect request latency or correctness;
- designing degradation for cache outages.

## Do not use when

- the cache is fully local and failure cannot cross the application boundary;
- the repository already has an established failure contract that remains unchanged.

## Repository inspection

Inspect cache store topology, timeout behavior, client configuration, source-of-truth cost, rate limits, fallback paths, circuit/bulkhead controls, and observability.

## Implementation procedure

1. Classify cache dependency as optional, degradable, or critical.
2. Define timeout/failure behavior.
3. Bound source fallback load.
4. Preserve correctness and authorization semantics.
5. Observe fallback/error rates.
6. Test cache timeout, connection failure, invalid value, and recovery.

## Example

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_CACHE_URL"),
    connect_timeout: 0.2, read_timeout: 0.2, write_timeout: 0.2,
    reconnect_attempts: 0,
    # A cache outage becomes a miss, reported once, not a failed request.
    error_handler: ->(method:, returning:, exception:) {
      Rails.error.report(exception, handled: true, context: { cache_method: method })
    }
  }
end
```

## Failure modes

- fail-open behavior exposes wrong data;
- cache outage creates source-of-truth thundering herd;
- unbounded cache timeouts extend request latency;
- fallback bypasses authorization;
- corrupted cache values are trusted;
- repeated store failures are invisible.

## Testing

Use deterministic cache-store doubles or repository-provided failure hooks to verify timeout/error/fallback behavior and recovery.

## Review checklist

- [ ] dependency classification
- [ ] bounded timeout
- [ ] bounded fallback load
- [ ] authorization preserved
- [ ] invalid values rejected
- [ ] metrics/diagnostics exist

## Related skills

rails-caching, rails-reliability-engineering, rails-observability, rails-security, rails-performance
