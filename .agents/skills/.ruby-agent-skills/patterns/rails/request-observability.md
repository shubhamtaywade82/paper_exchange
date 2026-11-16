---
name: request-observability
description: Add request correlation, logging, and metrics at the existing Rails request boundary.
family: rails
---

# Request Observability

## Problem
Production requests are hard to diagnose when logs, metrics, and errors cannot be correlated.

## Use when
A request path needs explicit correlation, structured logs, duration/status metrics, or error context.

## Implementation procedure
1. Inspect existing request ID/log-tag conventions.
2. Reuse Rails/request context already available.
3. Define minimal event fields.
4. Add instrumentation at meaningful boundaries.
5. Keep metric dimensions low-cardinality.
6. Filter sensitive parameters before logging.
7. Test correlation/event emission.

## Example

```ruby
# One structured line per request, correlated by request id, from Rails instrumentation.
ActiveSupport::Notifications.subscribe("process_action.action_controller") do |event|
  payload = event.payload
  Rails.logger.info(
    event: "request.completed",
    request_id: payload[:request].request_id,
    controller: payload[:controller], action: payload[:action],
    status: payload[:status], duration_ms: event.duration.round(1),
    db_ms: payload[:db_runtime]&.round(1), view_ms: payload[:view_runtime]&.round(1)
  )
end
# Parameters are omitted (filter_parameters already scrubs, but they are not needed here).
```

## Failure modes
- duplicate correlation identifiers
- raw IDs/user strings as metric labels
- full request bodies in logs
- instrumentation that mutates business behavior

## Testing
Assert structured event fields and request correlation rather than exact log formatting when possible.

## Review checklist
- request ID preserved
- logs are minimal
- metrics have bounded dimensions
- sensitive data filtered
- instrumentation is side-effect free

## Repository inspection

Inspect the repository's runtime/version, existing conventions, neighboring tests or implementation patterns, and the actual owning boundary before applying this pattern.

## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
## Do not use when

Do not use when there is no request-level correlation, logging, metric, or diagnostic requirement.
