---
name: dependency-failure-boundary
description: Classify a dependency's criticality and define bounded failure behavior before adding resilience mechanisms.
family: rails
---

# Dependency Failure Boundary

## Problem

Dependencies are treated uniformly even though some are critical, some degradable, and some optional.

## Use when

Reviewing external services, databases, caches, providers, or internal service dependencies.

## Do not use when

There is no independent dependency or failure behavior is entirely local.

## Repository inspection

Inspect dependency purpose, user journey, timeout, retry, concurrency, fallback, circuit state, ownership, and observability.

## Implementation procedure

1. Identify the user behavior requiring the dependency.
2. Classify it as critical, degradable, optional, or asynchronous.
3. Define timeout and retry semantics.
4. Define fallback/degraded behavior.
5. Define containment boundary.
6. Instrument dependency success, latency, and saturation.
7. Test dependency outage and recovery.

## Example

```ruby
# Classified per dependency: critical fails the request, degradable returns a
# fallback, optional is skipped.
class ProductPage
  def initialize(product) = @product = product

  def data
    {
      product: @product,                                   # critical: database
      recommendations: recommendations_or_empty,           # degradable
      reviews_badge: (ReviewsService.badge(@product) rescue nil) # optional
    }
  end

  private

  def recommendations_or_empty
    Recommendations.for(@product, timeout: 0.3)
  rescue Recommendations::Unavailable
    []
  end
end
```

## Failure modes

- optional dependency accidentally made critical
- fallback violates correctness or authorization
- timeout too long for request budget
- retries overwhelm dependency
- failure ownership unclear

## Testing

Test timeout, outage, degraded behavior, recovery, and observability at the dependency boundary.

## Review checklist

- [ ] criticality explicit
- [ ] user impact explicit
- [ ] timeout/retry explicit
- [ ] fallback explicit
- [ ] containment explicit
- [ ] recovery tested

## Related skills

- rails-reliability-engineering
- rails-api-integration
- rails-observability
- rails-distributed-systems
