---
name: authentication-context-propagation
description: Carry actor and tenant attribution across jobs, mailers, realtime connections, events, and services without serializing live credentials.
family: rails
---

# Authentication Context Propagation

## Problem

Authenticated request context crosses asynchronous or realtime boundaries. Copying session cookies or current-user objects into those boundaries creates fragile impersonation and secret exposure.

## Use when

A request triggers a job, mailer, Action Cable action, event, audit record, or downstream service call requiring actor attribution.

## Do not use when

The downstream operation is fully anonymous and has no actor or tenant semantics.

## Repository inspection

Inspect current-user implementation, job arguments, tenant context, authorization policies, audit events, Action Cable connection auth, and downstream service contracts.

## Implementation procedure

1. Classify the actor context.
2. Separate actor attribution from credential material.
3. Propagate stable actor and tenant identifiers only when required.
4. Re-resolve current authorization state at execution boundaries.
5. Never serialize cookies, passwords, or bearer credentials.
6. Define behavior when actor is deleted or disabled.
7. Add tests for missing/stale context.
8. Preserve correlation IDs separately from authorization.

## Example

```ruby
# The job receives ids, never the session cookie or a Current.user object,
# and re-checks that the actor may still perform the action.
class ExportJob < ApplicationJob
  def perform(user_id:, account_id:, export_id:)
    user = User.find(user_id)
    account = user.accounts.find_by(id: account_id)
    return unless account && ExportPolicy.new(user, account).create?

    account.exports.find(export_id).generate!
  end
end

ExportJob.perform_later(user_id: Current.user.id, account_id: Current.account.id, export_id: export.id)
```

## Failure modes

- serializing current_user
- passing session cookie to a job
- stale authorization trusted forever
- deleted actor causes arbitrary fallback identity
- tenant context inferred from user-controlled job arguments

## Testing

Test actor attribution, disabled/deleted actor behavior, cross-tenant rejection, and absence of credentials.

## Review checklist

- [ ] actor vs credential separated
- [ ] stable identifiers used
- [ ] authorization re-evaluated
- [ ] missing actor behavior explicit
- [ ] no secret serialization

## Related skills

- rails-authentication
- rails-active-job
- rails-action-cable
- rails-security-engineering

