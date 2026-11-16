---
name: middleware-rate-limit-boundary
description: Apply rate limiting at the correct infrastructure boundary with explicit capacity and consistency semantics.
family: rails
---
# Middleware Rate Limit Boundary

## Problem
An in-process limiter can be bypassed across workers or instances and can become an unbounded memory leak.

## Use when
Rate limiting is transport/request based and belongs before expensive downstream work.

## Do not use when
The limit depends on resource ownership or a business rule better enforced after authentication/authorization.

## Repository inspection
Inspect deployment topology, existing rate-limit infrastructure, identity source, trusted proxy behavior, store availability, and failure policy.

## Implementation procedure
Define keying, window/token semantics, store ownership, response contract, fail-open/closed behavior, and cleanup.

## Example

```ruby
# config/initializers/rack_attack.rb — counters in the shared cache, not per-process hashes.
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("RATE_LIMIT_REDIS_URL"))

Rack::Attack.throttle("api/ip", limit: 300, period: 1.minute) do |request|
  request.ip if request.path.start_with?("/api/")
end

Rack::Attack.throttle("logins/email", limit: 5, period: 20.minutes) do |request|
  request.params["email_address"].to_s.downcase.strip.presence if request.post? && request.path == "/session"
end

# request.ip is only trustworthy once config.action_dispatch.trusted_proxies matches the load balancer.
```

## Failure modes
Per-process bypass, spoofed client identity, store outage amplification, and unbounded local state.

## Testing
Test limits, reset behavior, concurrency, multi-process assumptions where possible, and store failure behavior.

## Review checklist
[ ] key trusted
[ ] topology accounted for
[ ] bounded state
[ ] failure policy explicit

## Related skills
rails-rack-middleware-engineering, rails-reliability-engineering, rails-security-engineering
