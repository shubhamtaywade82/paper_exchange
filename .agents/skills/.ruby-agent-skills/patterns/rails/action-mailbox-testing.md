---
name: action-mailbox-testing
description: Test Action Mailbox ingress, routing, mailbox processing, failure, security, and idempotency deterministically without live email providers.
family: rails
---

# Action Mailbox Testing

## Problem

Inbound email tests become slow and unreliable when they depend on real provider webhooks, SMTP, cloud storage, or production credentials.

## Use when

- adding mailbox behavior;
- changing routing or ingress;
- adding security controls;
- fixing duplicate/failure bugs.

## Do not use when

- a higher-level provider contract is the only behavior under test; use the provider adapter boundary instead.

## Repository inspection

Inspect ActionMailbox::TestCase conventions, ActionMailbox::TestHelper, fixtures, Active Storage test service, Active Job test adapter, and request/integration conventions.

## Implementation procedure

1. Use the repository's established mailbox test base.
2. Use receive_inbound_email_from_mail, fixture, or raw-source helpers.
3. Assert domain effects at the owning model/service boundary.
4. Assert bounce/failure status when it is part of the contract.
5. Test duplicates using the same stable message identity.
6. Test tenant/security rejection explicitly.
7. Keep provider authentication tests at the ingress request boundary.
8. Keep ordinary tests independent of external email infrastructure.

## Example

```ruby
class RepliesMailboxTest < ActionMailbox::TestCase
  test "creates one reply per message id" do
    2.times do
      receive_inbound_email_from_mail(
        from: customers(:sam).email,
        to: "reply+#{tickets(:open).reply_token}@example.test",
        message_id: "abc-123@example.test",
        body: "Thanks!"
      )
    end

    assert_equal 1, tickets(:open).replies.where(message_id: "abc-123@example.test").count
  end

  test "unknown sender is bounced" do
    inbound = receive_inbound_email_from_mail(from: "stranger@example.test", to: "support@example.test", body: "hi")
    assert inbound.bounced?
  end
end
```

## Failure modes

- live provider in unit/system tests;
- asserting only InboundEmail status while the domain effect is wrong;
- no duplicate coverage;
- no cross-tenant negative case;
- raw-message snapshots containing secrets.

## Testing

At minimum cover route selection, success, bounce/rejection, transient failure, duplicate delivery, cross-tenant rejection, attachment boundary, redaction, and enqueue semantics.

## Review checklist

- [ ] deterministic test inputs
- [ ] domain outcome asserted
- [ ] failure state asserted where relevant
- [ ] duplicate/replay test
- [ ] cross-tenant/security negative test
- [ ] external provider isolated
- [ ] no sensitive fixture leakage

## Related skills

- skills/rails-action-mailbox/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/rails-security/SKILL.md
