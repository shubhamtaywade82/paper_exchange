---
name: health-endpoint
description: Define Rails health and readiness semantics without coupling liveness to every dependency.
family: rails
---

# Health Endpoint

## Problem
Infrastructure needs deterministic health signals while application dependency failures may be transient or recoverable.

## Use when
Adding or reviewing Rails health, readiness, liveness, or dependency endpoints.

## Implementation procedure
1. Determine whether the endpoint is liveness, readiness, or dependency-specific.
2. Prefer Rails built-in health semantics when they match the requirement.
3. Add only necessary dependency checks.
4. Keep checks cheap and deterministic.
5. Do not expose internal failure details.
6. Test healthy and unhealthy states.

## Example

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check # liveness: process boots and serves
  get "ready" => "readiness#show"                           # readiness: can take traffic
end

# app/controllers/readiness_controller.rb
class ReadinessController < ActionController::API
  def show
    ActiveRecord::Base.connection.select_value("SELECT 1")
    head :ok
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn(event: "readiness.failed", error: e.class.name)
    head :service_unavailable
  end
end
# Optional dependencies (search, email) stay out of readiness: their outage
# must not remove every pod from the load balancer.
```

## Failure modes
- database/third-party outages causing unnecessary process restarts
- expensive health checks
- leaking internal exception details
- conflating liveness and readiness

## Testing
Assert status and response contract for each intended health state.

## Review checklist
- purpose is explicit
- dependency checks are justified
- response is deterministic
- no sensitive diagnostics leak

## Repository inspection

Inspect the repository's runtime/version, existing conventions, neighboring tests or implementation patterns, and the actual owning boundary before applying this pattern.

## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
## Do not use when

Do not use when the task is unrelated to process health, readiness, liveness, or dependency availability.
