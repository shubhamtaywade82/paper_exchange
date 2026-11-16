---
name: action-mailbox-processing-lifecycle
description: Model Action Mailbox processing around explicit prerequisites, domain work, failure classification, and framework status transitions.
family: rails
---

# Action Mailbox Processing Lifecycle

## Problem

Mailbox code often mixes routing, eligibility, domain mutation, external calls, and error handling into one unbounded process method.

## Use when

- adding a mailbox;
- refactoring mailbox callbacks;
- reviewing failed/bounced processing;
- integrating jobs or external dependencies.

## Do not use when

- the change only affects provider transport authentication.

## Repository inspection

Inspect mailbox callbacks, domain services, transaction boundaries, rescue handlers, jobs, mailers, and status/failure conventions.

## Implementation procedure

1. Put cheap prerequisites in before_processing.
2. Resolve sender/recipient/resource context.
3. Authorize the operation.
4. Perform domain changes in the owning transaction.
5. Enqueue follow-up work after the required commit boundary.
6. Classify permanent versus transient failure.
7. Use bounce/reject for business-invalid mail and failed/retryable handling for transient defects.
8. Emit lifecycle telemetry.

## Example

```ruby
class OrdersMailbox < ApplicationMailbox
  # Cheap, deterministic prerequisites only.
  before_processing :ensure_sender_is_customer

  # The mailbox orchestrates; domain rules live in the importer, and slow
  # follow-up work goes to a job after the record is committed.
  def process
    order = Orders::FromEmail.new(customer: @customer, mail: mail).call
    OrderConfirmationJob.perform_later(order)
  end

  private

  def ensure_sender_is_customer
    @customer = Customer.find_by(email: mail.from&.first)
    bounce_with(OrdersMailer.unknown_customer(inbound_email)) unless @customer
  end
end
```

## Failure modes

- broad rescue marks programmer errors as success;
- external call inside a long DB transaction;
- job enqueued before required commit;
- bounce used for every failure;
- callback performs unrelated domain work.

## Testing

Cover prerequisite rejection, success, transient failure, permanent rejection, callback ordering, and post-commit job behavior.

## Review checklist

- [ ] prerequisite boundary explicit
- [ ] authorization before mutation
- [ ] transaction owner explicit
- [ ] async boundary explicit
- [ ] failure classes explicit
- [ ] framework status remains truthful

## Related skills

- skills/rails-action-mailbox/SKILL.md
- skills/rails-active-job/SKILL.md
- skills/rails-database-engineering/SKILL.md
- skills/rails-reliability-engineering/SKILL.md
