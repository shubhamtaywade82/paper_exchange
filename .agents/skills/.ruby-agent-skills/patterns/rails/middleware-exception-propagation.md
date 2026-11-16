---
name: middleware-exception-propagation
description: Preserve intentional exception ownership across middleware.
family: rails
---
# Middleware Exception Propagation

## Problem
A broad middleware rescue can hide application failures or bypass Rails error handling and telemetry.

## Use when
Middleware must translate, classify, or instrument a known failure boundary.

## Do not use when
Generic error swallowing or replacing framework exception handling is proposed without a contract.

## Repository inspection
Inspect Rails exception handling, rescue_from usage, error reporting, environment behavior, and upstream expectations.

## Implementation procedure
Rescue only the owned exception classes, preserve cause/context, emit telemetry, and return a response only when the middleware contract requires it.

## Example

```ruby
class RequestTimingMiddleware
  def initialize(app) = @app = app

  def call(env)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @app.call(env)
  ensure
    # Observes every outcome, including exceptions, without swallowing them;
    # ActionDispatch::ShowExceptions and Rails.error keep ownership of the response.
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    Metrics.histogram("rack.request_seconds", elapsed)
  end
end

# Wrong:
#   rescue StandardError
#     [500, {}, ["error"]]   # hides the failure from Rails error reporting
```

## Failure modes
Hidden programmer errors, duplicate error reporting, incorrect status codes, and false-success responses.

## Testing
Test handled exceptions, unhandled exceptions, telemetry expectations, and environment-specific responses.

## Review checklist
[ ] rescue scope narrow
[ ] owner documented
[ ] original failure preserved
[ ] failure test exists

## Related skills
rails-rack-middleware-engineering, rails-observability, rails-action-controller
