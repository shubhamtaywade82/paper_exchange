---
name: authorization-audit-contract
description: Record bounded authorization outcomes without leaking sensitive policy inputs.
family: rails
---
# Authorization Audit Contract

## Problem
Security decisions are not explainable or observable, or logs expose sensitive data.

## Structure
Record actor, tenant, action, resource type/id, decision, bounded reason code, and correlation identifier as appropriate.

## Example

```ruby
class AuthorizationEvent < ApplicationRecord
  # Who, what, which resource, the decision, a bounded reason, and the
  # correlation id — never tokens, passwords, or request bodies.
  REASONS = %w[owner admin not_member wrong_tenant revoked].freeze
  validates :reason, inclusion: { in: REASONS }
end

AuthorizationEvent.create!(
  actor_id: current_user.id, tenant_id: current_tenant.id,
  action: "invoice.refund", resource_type: "Invoice", resource_id: invoice.id,
  allowed: false, reason: "not_member", request_id: request.request_id
)
```

## Failure modes
Passwords/tokens in logs, arbitrary policy internals, and unbounded resource data.

## Testing
Assert audit events exist for security-critical decisions and contain no credential material.

## Use when

Use this pattern when the named security boundary is part of the requested change.

## Do not use when

Do not introduce this pattern when a simpler repository-consistent boundary already proves the required contract.

## Repository inspection

Inspect the existing authorization mechanism, entry points, resource ownership, tenant scope, tests, and versioned dependencies.

## Implementation procedure

Define the authoritative boundary, adapt to repository conventions, preserve denial semantics, and add focused regression coverage.

## Review checklist

[ ] authoritative mechanism preserved
[ ] bypass paths reviewed
[ ] tenant/resource scope explicit
[ ] rejection behavior tested

## Related skills

rails-authorization, rails-authentication, rails-security, rails-test-engineering
