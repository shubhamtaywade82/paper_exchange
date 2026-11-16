---
name: graceful-degradation
description: Preserve critical user behavior with explicit stale, reduced, asynchronous, or fallback responses during dependency or capacity failures.
family: rails
---

# Graceful Degradation

## Problem

A non-critical dependency failure causes the entire user journey to fail even though a lower-fidelity behavior is acceptable.

## Use when

An operation has optional enrichment, cached/stale data, asynchronous completion, reduced functionality, or a safe fallback.

## Do not use when

Returning a degraded result would violate correctness, authorization, financial, or safety requirements.

## Repository inspection

Inspect dependency criticality, cache freshness, authorization, feature flags, data correctness, user messaging, and recovery behavior.

## Implementation procedure

1. Define the normal contract.
2. Define the degraded contract.
3. State exactly what may be missing/stale/delayed.
4. Verify security and authorization remain correct.
5. Instrument degraded responses.
6. Define exit conditions and restoration.
7. Test both normal and degraded paths.

## Example

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])
    # Recommendations are optional: a failure renders the page without them.
    @recommendations = fetch_recommendations
  end

  private

  def fetch_recommendations
    Recommendations::Client.new(timeout: 0.3).for(@product)
  rescue Recommendations::Client::Error, Timeout::Error => e
    Rails.error.report(e, handled: true, context: { product_id: @product.id })
    [] # degraded: no recommendations, never stale prices or other users' data
  end
end
```

## Failure modes

- stale data presented as authoritative
- fallback crosses tenant/auth boundaries
- degradation becomes permanent
- users cannot distinguish pending from completed work
- fallback dependency shares the same failure domain

## Testing

Test dependency failure, fallback/stale path, authorization, recovery, and observability.

## Review checklist

- [ ] degraded behavior explicit
- [ ] freshness/correctness bound
- [ ] authorization preserved
- [ ] user semantics explicit
- [ ] recovery path exists
- [ ] degraded usage observable

## Related skills

- rails-reliability-engineering
- rails-api-integration
- rails-observability
- rails-performance
