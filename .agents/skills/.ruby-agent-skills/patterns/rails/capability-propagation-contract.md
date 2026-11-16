---
name: capability-propagation-contract
description: Authorization Capability Propagation Contract
family: security
---
# Authorization Capability Propagation Contract

## Problem
Ambient current-user state does not compose safely across asynchronous or nested boundaries.

## Use when
A downstream operation requires proof that an upstream authorization decision was made.

## Do not use when
A fresh authorization decision is simpler and available at the boundary.

## Repository inspection
Inspect caller/callee relationships, capability shape, expiry, audience, and serialization needs.

## Implementation procedure
Pass a narrow, non-forgeable or explicitly scoped capability object/context with clear lifetime and audience.

## Example

```ruby
# Instead of ambient Current.user in a job, pass a narrow, signed capability
# that states exactly what may be done, by whom, until when.
capability = Rails.application.message_verifier(:export).generate(
  { "actor_id" => current_user.id, "report_id" => report.id, "action" => "export" },
  purpose: :report_export, expires_in: 15.minutes
)
ExportReportJob.perform_later(capability)

class ExportReportJob < ApplicationJob
  def perform(capability)
    grant = Rails.application.message_verifier(:export).verify(capability, purpose: :report_export)
    actor = User.find(grant.fetch("actor_id"))
    Reports::Export.call(actor: actor, report: actor.account.reports.find(grant.fetch("report_id")))
  end
end
```

## Failure modes
Overbroad bearer capability, serialized credentials, confused audience, indefinite lifetime.

## Testing
Test capability misuse, wrong resource/action, expiry, and caller substitution.

## Review checklist
[ ] narrow scope [ ] audience [ ] lifetime [ ] non-forgeable semantics

## Related skills
rails-cross-boundary-authorization-security, rails-dependency-injection