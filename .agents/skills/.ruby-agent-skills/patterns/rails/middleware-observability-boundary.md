---
name: middleware-observability-boundary
description: Instrument middleware without creating a second telemetry contract.
family: rails
---
# Middleware Observability Boundary

## Problem
Middleware-specific logging can duplicate Rails request telemetry or expose sensitive request data.

## Use when
Adding latency, error, short-circuit, or middleware-specific metrics/logging.

## Do not use when
Existing request instrumentation already provides the required evidence and no middleware-specific signal is needed.

## Repository inspection
Inspect Rails.error, ActiveSupport::Notifications, tracing, log tags, and current dashboards/alerts.

## Implementation procedure
Reuse existing instrumentation primitives, add only missing dimensions, bound cardinality, and exclude sensitive values.

## Example

```ruby
# Reuse Rails' request id and tagged logging instead of a parallel log line per request.
Rails.application.configure do
  config.log_tags = [:request_id]
  config.filter_parameters += %i[password token secret otp]
end

# A middleware adds only what Rails does not already record.
class TenantTagMiddleware
  def initialize(app) = @app = app

  def call(env)
    tenant = env["HTTP_HOST"].to_s.split(".").first
    Rails.logger.tagged("tenant=#{tenant}") { @app.call(env) }
  end
end
# No headers, cookies, or bodies are logged here.
```

## Failure modes
Duplicate events, high-cardinality metrics, missing exception telemetry, and secret leakage.

## Testing
Test event emission for success/failure/short-circuit paths where the repository has instrumentation tests.

## Review checklist
[ ] reuse existing telemetry
[ ] bounded cardinality
[ ] sensitive data excluded
[ ] failure paths visible

## Related skills
rails-rack-middleware-engineering, rails-observability
