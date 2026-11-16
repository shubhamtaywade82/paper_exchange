---
name: middleware-short-circuit-contract
description: Short-circuit requests only when the middleware owns the rejection or response.
family: rails
---
# Middleware Short Circuit Contract

## Problem
Early responses can accidentally bypass required authentication, telemetry, cleanup, or downstream work.

## Use when
Rate limiting, trusted-host rejection, infrastructure-owned static responses, or other explicitly owned early exits are required.

## Do not use when
A business decision or resource authorization is being moved out of its owning layer.

## Repository inspection
Inspect security/authentication ownership, required telemetry, headers, status conventions, and response lifecycle.

## Implementation procedure
Define the status, headers, body, downstream skip semantics, and observability for the short-circuit path.

## Example

```ruby
class MaintenanceModeMiddleware
  ALLOWED = ["/up", "/ready"].freeze

  def initialize(app) = @app = app

  def call(env)
    return @app.call(env) unless Flipper.enabled?(:maintenance_mode)
    return @app.call(env) if ALLOWED.include?(env["PATH_INFO"])

    # Short-circuit: downstream (auth, controllers, jobs) does not run.
    # Inserted after ActionDispatch::RequestId so the 503 still carries X-Request-Id.
    [503, { "content-type" => "text/plain", "retry-after" => "120", "cache-control" => "no-store" },
     ["Down for maintenance"]]
  end
end

Rails.application.config.middleware.insert_after ActionDispatch::RequestId, MaintenanceModeMiddleware
```

## Failure modes
False-success responses, bypassed controls, missing headers, and inconsistent telemetry.

## Testing
Test both short-circuit and delegated paths plus required headers and body behavior.

## Review checklist
[ ] owner explicit
[ ] downstream skip intentional
[ ] response complete
[ ] telemetry/security preserved

## Related skills
rails-rack-middleware-engineering, rails-security-engineering, rails-observability
