---
name: action-mailbox-tenant-association
description: Resolve inbound email to a tenant or resource through authoritative application state and preserve isolation downstream.
family: rails
---

# Action Mailbox Tenant Association

## Problem

Email aliases often encode routing information, but routing identifiers are not authorization. Multi-tenant applications need an explicit ownership decision before mutation.

## Use when

- inbound mail creates or changes tenant-scoped records;
- reply addresses encode tenant/resource context;
- support addresses map to accounts/projects/tickets.

## Do not use when

- the application is single-tenant and has no resource-scoped authorization.

## Repository inspection

Inspect recipient/alias models, user identity policy, tenant membership, resource authorization, and downstream job/event payloads.

## Implementation procedure

1. Resolve candidate tenant/resource.
2. Verify sender eligibility in that scope.
3. Authorize the requested operation.
4. Persist the tenant/resource association with domain state.
5. Propagate tenant identity to downstream jobs/events.
6. Add cross-tenant negative tests.

## Example

```ruby
class TenantInboxMailbox < ApplicationMailbox
  # "acme@in.example.com" routes the email to a tenant, but the sender must
  # still be a member of that tenant before anything is created.
  def process
    tenant = Tenant.find_by!(inbox_slug: mail.to.first.split("@").first)
    member = tenant.users.find_by(email: mail.from&.first&.downcase)
    return bounce_with(InboxMailer.not_a_member(inbound_email)) unless member

    tenant.documents.create!(author: member, subject: mail.subject.to_s.first(200), body: mail.decoded)
  end
end
```

## Failure modes

- tenant inferred only from email local-part;
- sender verified globally but not for target tenant;
- job/event omits tenant identity;
- replay bypasses current authorization.

## Testing

Test valid association, nonexistent alias, revoked sender, cross-tenant target, and replay after authorization changes.

## Review checklist

- [ ] owner resolution authoritative
- [ ] sender eligibility scoped
- [ ] resource authorization enforced
- [ ] tenant identity persisted/propagated
- [ ] cross-tenant tests exist

## Related skills

- skills/rails-action-mailbox/SKILL.md
- patterns/rails/tenant-isolation-review.md
- skills/rails-security-engineering/SKILL.md
