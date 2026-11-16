---
name: background-reauthorization-composition
description: Background Re-Authorization Composition
family: security
---
# Background Re-Authorization Composition

## Problem
Permission or ownership can change between enqueue and execution.

## Use when
A security-sensitive job is delayed or retried.

## Do not use when
The job performs a truly non-sensitive operation whose authorization is immutable and encoded by another invariant.

## Repository inspection
Inspect serialized arguments, membership state, tenant relationships, retries, and job timing.

## Implementation procedure
Serialize stable identities only; re-resolve current authorization/context when the job executes.

## Example

```ruby
# Web and job paths share one authorizing operation; the job calls it again
# at execution time instead of trusting the enqueue-time check.
class Reports::Export
  def self.call(actor:, report:)
    raise Authorization::Forbidden unless ReportPolicy.new(actor, report).export?

    report.exports.create!(requested_by: actor).tap(&:generate!)
  end
end

class ExportReportJob < ApplicationJob
  def perform(actor_id, report_id)
    actor = User.find(actor_id)
    Reports::Export.call(actor: actor, report: actor.account.reports.find(report_id))
  rescue Authorization::Forbidden
    Rails.logger.info("export skipped: permission revoked", actor_id:, report_id:)
  end
end
```

## Failure modes
Revoked membership still performs sensitive mutation, stale tenant access, bearer context in queue.

## Testing
Revoke access after enqueue and assert safe rejection at execution.

## Review checklist
[ ] current authorization checked [ ] stable identities [ ] revoke test

## Related skills
rails-cross-boundary-authorization-security, rails-active-job