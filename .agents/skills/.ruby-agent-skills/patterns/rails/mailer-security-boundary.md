---
name: mailer-security-boundary
description: Review outbound email as a privacy and authorization boundary for recipients, tenant data, links, attachments, and secrets.
family: rails
---

# Mailer Security Boundary

## Problem

Email can export sensitive data outside application authentication and authorization boundaries.

## Use when

- sending tenant/private data;
- sending password/reset/security notifications;
- attaching files;
- changing recipients or CC/BCC;
- reviewing staging/production email safety.

## Do not use when

- the message is truly public and has no private data or privileged capability.

## Repository inspection

Inspect authorization, tenant resolution, consent/preferences, data classification, token lifecycle, attachment access, mail logs, and environment delivery safeguards.

## Implementation procedure

1. Classify message data.
2. Verify recipient eligibility.
3. Verify tenant/resource scope.
4. Review URLs/capabilities and token lifetime.
5. Review attachment authorization.
6. Filter logs/errors.
7. Add negative security tests.
8. Verify staging cannot accidentally deliver externally.

## Example

```ruby
class InvoiceMailer < ApplicationMailer
  def issued(invoice)
    @invoice = invoice
    recipient = invoice.account.billing_contact
    # Recipient comes from authoritative account state, never from request params.
    raise ArgumentError, "billing contact outside account" unless recipient.account_id == invoice.account_id

    # Link to the authenticated app instead of attaching the full PDF.
    @invoice_url = invoice_url(invoice)
    mail(to: recipient.email, subject: t(".subject", number: invoice.number))
  end
end
# Password reset tokens: signed, expiring (generates_token_for), never logged;
# config.filter_parameters covers :token.
```

## Failure modes

- cross-tenant recipients;
- sensitive values in logs;
- reusable security tokens;
- unauthorized attachments;
- staging accidentally emailing real users.

## Testing

Test authorized/unauthorized recipients, tenant separation, sensitive-field filtering, and unsafe-environment delivery safeguards.

## Review checklist

- [ ] recipient authorized
- [ ] tenant scope enforced
- [ ] tokens minimized/lifetime understood
- [ ] attachments authorized
- [ ] logs filtered
- [ ] environment safeguard

## Related skills

rails-action-mailer, rails-security, rails-security-engineering, rails-authentication
