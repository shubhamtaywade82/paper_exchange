---
name: event-consumer-authorization-contract
description: Event Consumer Authorization Contract
family: security
---
# Event Consumer Authorization Contract

## Problem
An event may arrive after membership, ownership, or role state has changed.

## Use when
A consumer performs a security-sensitive side effect from an event.

## Do not use when
The event only updates public, non-sensitive derived data.

## Repository inspection
Inspect event envelope, actor context, tenant identity, consumer timing, retries, and authorization state.

## Implementation procedure
Carry stable context needed for policy evaluation and re-check current authorization/ownership before sensitive effects.

## Example

```ruby
# The event carries identities only; permission is re-checked when it is consumed.
class ProjectExportRequestedConsumer
  def call(event)
    user = User.find_by(id: event.fetch("user_id"))
    project = Project.find_by(id: event.fetch("project_id"))
    return log_denied(event, "missing") unless user && project
    # Membership may have been revoked after the event was published.
    return log_denied(event, "forbidden") unless ProjectPolicy.new(user, project).export?

    ProjectExport.create!(project:, requested_by: user, source_event_id: event.fetch("id"))
  end

  private

  def log_denied(event, reason)
    Rails.logger.info(event: "project_export.denied", event_id: event.fetch("id"), reason:)
    :denied # acknowledged, not retried: retrying cannot change the decision
  end
end
```

## Failure modes
Stale authorization, replayed events bypassing current policy, cross-tenant side effects.

## Testing
Test replay after revocation and events from the wrong tenant.

## Review checklist
[ ] current policy check [ ] replay-safe [ ] tenant context

## Related skills
rails-cross-boundary-authorization-security, rails-event-driven-messaging, rails-authorization