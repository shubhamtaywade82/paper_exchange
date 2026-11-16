---
name: middleware-testing
description: Test middleware behavior at the Rack boundary and stack integration boundary.
family: rails
---
# Middleware Testing

## Problem
Controller-only tests can miss ordering, short-circuit, body, exception, and environment contracts.

## Use when
Adding or changing custom middleware or middleware registration.

## Do not use when
A change has no middleware behavior and existing higher-level tests already cover the relevant contract.

## Repository inspection
Inspect existing Rack/request/system test conventions and available Rails middleware test helpers.

## Implementation procedure
Write focused Rack tests for the component, integration tests for registration/order, and system tests only for user-visible browser behavior.

## Example

```ruby
require "test_helper"
require "rack/mock"

class MaintenanceModeMiddlewareTest < ActiveSupport::TestCase
  setup do
    @downstream_called = false
    app = ->(_env) { @downstream_called = true; [200, {}, ["ok"]] }
    @middleware = MaintenanceModeMiddleware.new(app)
  end

  test "short-circuits with 503 and does not call downstream" do
    Flipper.enable(:maintenance_mode)
    status, headers, body = @middleware.call(Rack::MockRequest.env_for("/orders"))
    assert_equal 503, status
    assert_equal "120", headers["retry-after"]
    assert_equal ["Down for maintenance"], body.to_a
    refute @downstream_called
  ensure
    Flipper.disable(:maintenance_mode)
  end

  test "health checks pass through" do
    Flipper.enable(:maintenance_mode)
    status, = @middleware.call(Rack::MockRequest.env_for("/up"))
    assert_equal 200, status
  ensure
    Flipper.disable(:maintenance_mode)
  end
end
```

## Failure modes
Tests that pass while middleware is absent, misordered, or leaking state.

## Testing
Cover delegation, early exit, headers/status, exceptions, body lifecycle, and concurrency/security cases as applicable.

## Review checklist
[ ] direct boundary test
[ ] registration/order test
[ ] failure path
[ ] no redundant browser test

## Related skills
rails-rack-middleware-engineering, rails-test-engineering
