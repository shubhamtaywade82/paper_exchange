---
name: catch-all-route-boundary
description: Use when adding wildcards, catch-all routes, SPA fallbacks, legacy redirects, or broad fallback routing.
family: rails
---

# Catch-All Route Boundary

## Problem

Wildcard and fallback routes can absorb requests that should have been handled by specific endpoints, create security surprises, or hide routing regressions.

## Use when

- adding a wildcard segment;
- implementing an SPA fallback;
- adding a final 404 or legacy redirect route;
- reviewing broad route patterns.

## Do not use when

- ordinary resourceful routes already express the desired contract.

## Repository inspection

Inspect route order, wildcard segments, existing 404 behavior, redirect conventions, frontend fallback behavior, and negative route tests.

## Implementation procedure

1. Define the exact fallback population.
2. Put narrow routes first.
3. Exclude sensitive/system paths where needed.
4. Define redirect status/target semantics explicitly.
5. Test intended misses and protected paths.

## Example

```ruby
Rails.application.routes.draw do
  resources :orders
  namespace :api do
    resources :orders, only: %i[index show]
  end

  # Last, and constrained: only HTML GETs that are not API, assets, or
  # Rails-internal paths reach the SPA shell.
  get "*path", to: "spa#show", constraints: ->(request) {
    request.format.html? && !request.path.start_with?("/api", "/rails", "/assets")
  }
end
```

## Failure modes

- fallback captures health/admin/API routes;
- user-controlled redirect target creates an open redirect;
- wildcard masks missing-route regressions;
- catch-all becomes an implicit authorization layer.

## Testing

Test intended fallback requests and important paths that must not fall through.

## Review checklist

- [ ] fallback population explicit
- [ ] order intentional
- [ ] redirect behavior safe
- [ ] important negative cases tested

## Related skills

rails-routing, rails-action-controller, rails-security, rails-test-engineering
