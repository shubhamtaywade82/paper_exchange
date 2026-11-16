---
name: diagnostic-context
description: Preserve stable, privacy-aware correlation context across requests, jobs, messages, dependencies, and deployment metadata.
family: rails
---

# Diagnostic Context

## Problem
Incidents take longer when operators cannot connect related telemetry across execution boundaries.

## Use when
- adding diagnostic context;
- crossing request/job/message/dependency boundaries;
- troubleshooting distributed failures.

## Do not use when
- a stable repository correlation mechanism already fully answers the need;
- adding context would expose sensitive values or create high-cardinality metrics.

## Repository inspection
Inspect request IDs, log tags, Rails.error context, job/message metadata, tracing, metric dimensions, and parameter filtering.

## Implementation procedure
1. Reuse the existing correlation identifier. 2. Propagate it through the owning boundary. 3. Add bounded context fields. 4. Filter secrets. 5. Keep metric labels low-cardinality. 6. Test request-to-async and dependency propagation where applicable.

## Example

```ruby
# One request id flows through logs, jobs, and outbound calls.
Rails.application.configure do
  config.log_tags = [:request_id]
end

class ApplicationJob < ActiveJob::Base
  around_perform do |job, block|
    Rails.logger.tagged("job:#{job.job_id}", "req:#{job.arguments.last.try(:[], :request_id)}") { block.call }
  end
end

class PaymentsClient
  def charge(payload) = @http.post("/charges", payload, "X-Request-Id" => Current.request_id)
end
```

## Failure modes
- duplicate correlation IDs;
- request IDs used as metric labels;
- credentials in context;
- inconsistent field names across systems;
- unbounded user input.

## Testing
Assert identifier propagation and sensitive-field filtering at the owning boundary without brittle full-log snapshots.

## Review checklist
- [ ] existing ID reused; - [ ] propagation explicit; - [ ] secrets filtered; - [ ] low cardinality; - [ ] tests cover transitions.

## Related skills
rails-incident-engineering, rails-observability, rails-event-driven-messaging, rails-distributed-systems