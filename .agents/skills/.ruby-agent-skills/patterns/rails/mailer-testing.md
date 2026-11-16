---
name: mailer-testing
description: Test Rails mailers deterministically across message contracts, previews, asynchronous delivery, and provider boundaries without live email services.
family: testing
---

# Mailer Testing

## Problem

Email changes can regress headers, templates, recipients, enqueue behavior, or delivery failures while superficial tests still pass.

## Use when

- adding or changing Action Mailer;
- reviewing email regressions;
- testing deliver_later or provider boundaries.

## Do not use when

- the task has no email delivery behavior.

## Repository inspection

Inspect test framework, mailer test helpers, Active Job test helpers, previews, existing external-boundary test doubles, and fixture conventions.

## Implementation procedure

1. Test the mailer message contract.
2. Test HTML/text and attachment behavior.
3. Test delivery-mode and queue assertions.
4. Test preview rendering where relevant.
5. Test provider adapter failure classification.
6. Test security/tenant-negative cases.
7. Avoid live SMTP/API calls.

## Example

```ruby
require "test_helper"

class OrderMailerDeliveryTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "placing an order enqueues exactly one confirmation" do
    assert_enqueued_emails 1 do
      post orders_path, params: { order: { sku: "BOOK-1", quantity: 1 } }
    end
    assert_enqueued_email_with OrderMailer, :confirmation, args: [Order.last]
  end

  test "failed order does not email" do
    assert_no_enqueued_emails do
      post orders_path, params: { order: { sku: "", quantity: 1 } }
    end
  end

  test "rendered email has both parts" do
    mail = OrderMailer.confirmation(orders(:placed))
    assert_equal %w[text/plain text/html], mail.parts.map(&:mime_type)
  end
end
```

## Failure modes

- asserting only that a mail was "sent";
- brittle full-MIME snapshots;
- live provider dependency;
- missing negative authorization tests;
- ignoring async queue semantics.

## Testing

Prefer focused assertions for recipients, subject, body fragments, headers, attachments, enqueue behavior, and provider outcomes.

## Review checklist

- [ ] deterministic
- [ ] contract-focused
- [ ] async semantics
- [ ] provider isolated
- [ ] security negatives
- [ ] preview where useful

## Related skills

rails-action-mailer, rails-test-engineering, rails-active-job, rails-api-integration
