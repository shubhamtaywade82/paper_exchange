---
name: action-mailbox-ingress-boundary
description: Define the external provider or MTA ingress boundary before Action Mailbox creates an InboundEmail.
family: rails
---

# Action Mailbox Ingress Boundary

## Problem

Inbound email crosses an external provider or mail-transfer boundary before Rails can route or process it.

## Use when

- configuring or changing Action Mailbox ingress;
- onboarding a provider/MTA;
- reviewing ingress authentication or payload limits;
- diagnosing webhook/relay duplicates or rejected messages.

## Do not use when

- the task is purely mailbox/domain logic after an InboundEmail exists.

## Repository inspection

Inspect config.action_mailbox.ingress, provider/MTA setup, credentials, reverse proxy limits, routes, ingress tests, and secret-management conventions.

## Implementation procedure

1. Identify provider/MTA and transport mode.
2. Define endpoint and raw-email format.
3. Define ingress authentication and credential owner.
4. Verify proxy/body-size/timeouts.
5. Define provider retry and duplicate expectations.
6. Keep provider-specific request parsing at the ingress boundary.
7. Add deterministic request/ingress tests.

## Example

```ruby
# config/environments/production.rb
Rails.application.configure do
  # One provider-specific ingress; its credential is rotated like any secret.
  config.action_mailbox.ingress = :postmark
  config.action_mailbox.incinerate_after = 30.days
end

# config/credentials/production.yml.enc
#   action_mailbox:
#     ingress_password: <generated, not committed in plain text>
#
# Postmark posts to /rails/action_mailbox/postmark/inbound_emails with basic
# auth "actionmailbox:<ingress_password>"; requests without it get 401.
```

## Failure modes

- unauthenticated ingress;
- provider credentials logged;
- body-size mismatch between proxy and application;
- provider-specific payload leaking into domain logic;
- duplicate provider retries treated as unique business events;
- raw message omitted by provider configuration.

## Testing

Test authentication failure, valid payload acceptance, malformed payload rejection, duplicate delivery, size limits, and redaction.

## Review checklist

- [ ] ingress mechanism identified
- [ ] authentication explicit
- [ ] payload/raw-message contract explicit
- [ ] size/timeouts bounded
- [ ] retry/duplicate behavior documented
- [ ] provider-specific code isolated
- [ ] secrets redacted

## Related skills

- skills/rails-action-mailbox/SKILL.md
- skills/rails-api-integration/SKILL.md
- skills/rails-security/SKILL.md
- skills/rails-security-engineering/SKILL.md
