---
name: action-mailbox-failure-quarantine
description: Contain malformed, poison, or operationally unsafe inbound email without silently losing business evidence.
family: rails
---

# Action Mailbox Failure and Quarantine

## Problem

Inbound failures can be transient, permanent, malicious, or caused by one poison message. Treating all failures as retries or all failures as drops creates outages or data loss.

## Use when

- adding retry/quarantine behavior;
- handling malformed messages;
- designing operator replay;
- diagnosing mailbox failure storms.

## Do not use when

- the task has no failure or recovery path.

## Repository inspection

Inspect Active Job retry/discard policy, Action Mailbox statuses, error reporting, retention, operator tooling, and incident/runbook conventions.

## Implementation procedure

1. Classify the failure before choosing retry/reject/quarantine.
2. Keep transient retry bounded.
3. Stop poison-message loops.
4. Preserve enough metadata for diagnosis within privacy limits.
5. Make replay explicit and authorized.
6. Preserve original message identity during replay.
7. Verify domain state before replaying.
8. Alert on actionable quarantine/backlog thresholds.

## Example

```ruby
class InvoiceMailbox < ApplicationMailbox
  MAX_ATTACHMENT_BYTES = 10.megabytes

  def process
    attachment = mail.attachments.find { |part| part.content_type.start_with?("application/pdf") }

    # Permanent, business-invalid: tell the sender, do not retry.
    return bounce_with(InvoiceMailer.missing_pdf(inbound_email)) unless attachment
    return bounce_with(InvoiceMailer.too_large(inbound_email)) if attachment.body.decoded.bytesize > MAX_ATTACHMENT_BYTES

    InvoiceImport.create!(message_id: mail.message_id, pdf: attachment.body.decoded)
  rescue ActiveRecord::RecordNotUnique
    # Duplicate delivery of an already-imported message: done, not failed.
  rescue Faraday::TimeoutError
    raise # transient: let the job retry
  end
end
```

## Failure modes

- infinite retries;
- automatic replay of poison mail;
- raw email exposed in alerts;
- operator replay without authorization;
- successful delivery after partial failure.

## Testing

Test bounded retries, permanent rejection, quarantine routing, replay authorization, duplicate safety, and recovery verification.

## Review checklist

- [ ] failure classes defined
- [ ] retry bounded
- [ ] poison messages contained
- [ ] evidence retention explicit
- [ ] replay authorized
- [ ] duplicate safety preserved

## Related skills

- skills/rails-action-mailbox/SKILL.md
- skills/rails-active-job/SKILL.md
- skills/rails-reliability-engineering/SKILL.md
- skills/rails-incident-engineering/SKILL.md
- patterns/rails/dead-letter-replay.md
