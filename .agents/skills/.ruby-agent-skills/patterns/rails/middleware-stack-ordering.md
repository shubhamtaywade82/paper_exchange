---
name: middleware-stack-ordering
description: Make middleware ordering an explicit behavioral contract.
family: rails
---
# Middleware Stack Ordering

## Problem
Two individually valid middleware components can produce incorrect behavior when their relative order changes.

## Use when
Adding, removing, or reordering middleware.

## Do not use when
A component has no stack interaction or ordering dependency.

## Repository inspection
Inspect config.middleware, bin/rails middleware output, environment-specific configuration, and tests.

## Implementation procedure
Identify producer/consumer and failure/security dependencies, then place middleware at the narrowest correct boundary and test the order.

## Example

```ruby
# Order is behavior: the limiter must see the client IP after proxy headers are trusted,
# and CORS must answer preflight before authentication rejects it.
Rails.application.config.middleware.insert_after ActionDispatch::RemoteIp, Rack::Attack
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://app.example.com"
    resource "/api/*", headers: :any, methods: %i[get post patch delete options]
  end
end

# Evidence, not assumption:
#   RAILS_ENV=production bin/rails middleware
# test/integration/middleware_order_test.rb
class MiddlewareOrderTest < ActiveSupport::TestCase
  test "rack attack runs after remote ip" do
    stack = Rails.application.middleware.map(&:klass)
    assert_operator stack.index(Rack::Attack), :>, stack.index(ActionDispatch::RemoteIp)
  end
end
```

## Failure modes
Headers missing, exceptions bypassed, security checks skipped, or observability initialized too late.

## Testing
Assert stack order where order is contractual and exercise the affected request path.

## Review checklist
[ ] order justified
[ ] environment differences inspected
[ ] order regression covered
[ ] no cosmetic reorder

## Related skills
rails-rack-middleware-engineering, rails-production-runtime, rails-security-engineering
