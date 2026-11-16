---
name: idempotent-job
description: Make a background job safe when execution can be repeated.
family: rails
---

# Idempotent Job

## Problem
Retries, redelivery, operator replay, or deployment recovery can execute a job more than once.

## Use when
A job performs durable or externally visible side effects.

## Do not use when
The job is provably pure and repeatable without side effects.

## Implementation procedure
1. Identify every side effect.
2. Define the duplicate-execution scenario.
3. Choose a durable idempotency key or state invariant.
4. Enforce uniqueness at the database/external API boundary when possible.
5. Keep the job retryable without corrupting state.
6. Test the duplicate path explicitly.

## Example

```ruby
class ChargeSubscriptionJob < ApplicationJob
  retry_on PaymentGateway::Timeout, wait: :polynomially_longer, attempts: 5

  def perform(invoice_id)
    invoice = Invoice.find(invoice_id)
    return if invoice.paid? # a duplicate run after success is a no-op

    # The provider deduplicates on the key, so a retry after an ambiguous timeout
    # cannot create a second charge.
    charge = PaymentGateway.charge(
      amount_cents: invoice.amount_cents,
      idempotency_key: "invoice-#{invoice.id}"
    )
    invoice.with_lock do
      invoice.update!(status: :paid, charge_id: charge.id) unless invoice.paid?
    end
  end
end
```

## Failure modes
- process-local mutex used as distributed idempotency
- check-then-act race without database constraint
- marking complete before the side effect
- retrying an external charge without an idempotency key

## Testing
Execute the job twice with the same logical input and assert the externally visible result occurs once.

## Review checklist
- durable key/invariant exists
- race is closed
- retry path is safe
- duplicate execution is tested

## Related skills
- rails-active-job
- rails-active-record
- rails-security
- ruby-concurrency

## Repository inspection

Inspect the repository's runtime/version, existing conventions, neighboring tests or implementation patterns, and the actual owning boundary before applying this pattern.
