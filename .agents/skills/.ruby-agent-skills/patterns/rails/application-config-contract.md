---
name: application-config-contract
description: Application Config Contract
family: rails
---
# Application Config Contract

## Problem
Application-owned settings need stable names, types, defaults, and access semantics.

## Use when
Adding config.x or another application namespace.

## Do not use when
Framework-owned behavior with an established Rails API.

## Repository inspection
Inspect existing config.x usage and consumers.

## Implementation procedure
Define one namespace and normalize values at the boundary.

## Example

```ruby
# config/application.rb — one namespaced, typed, validated settings object.
module Shop
  class Application < Rails::Application
    config.x.checkout.max_items = Integer(ENV.fetch("CHECKOUT_MAX_ITEMS", "100"))
    config.x.checkout.provider = ENV.fetch("CHECKOUT_PROVIDER", "stripe").to_sym
  end
end

# config/initializers/checkout.rb — fail at boot, not on the first request.
unless %i[stripe adyen].include?(Rails.configuration.x.checkout.provider)
  raise ArgumentError, "CHECKOUT_PROVIDER must be stripe or adyen"
end

Rails.configuration.x.checkout.max_items # read through one name everywhere
```

## Failure modes
Stringly-typed drift and duplicated parsing.

## Testing
Test default, configured, malformed, and missing states.

## Review checklist
[ ] namespace [ ] type [ ] default [ ] consumer contract

## Related skills
rails-initialization-configuration-engineering, ruby-clean-code
