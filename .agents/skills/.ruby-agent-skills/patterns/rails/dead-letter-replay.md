---
name: dead-letter-replay
description: Route terminal message failures to a controlled dead-letter workflow with safe inspection and replay.
family: rails
---

# Dead-Letter & Replay

## Problem

A poison or repeatedly failing message can block progress or create an infinite retry loop.

## Use when

Messages have bounded retry policies and operators need a safe recovery path.

## Do not use when

Failures can be safely corrected automatically within the normal retry budget.

## Repository inspection

Inspect broker dead-letter behavior, retention, message identity, failure metadata, access control, replay tooling, and consumer idempotency.

## Implementation procedure

1. Classify terminal failures.
2. Route after a bounded retry budget.
3. Preserve original message identity and safe failure metadata.
4. Restrict inspection/replay permissions.
5. Make remediation and replay selection explicit.
6. Rate-limit replay.
7. Preserve correlation/causation metadata.
8. Audit replay outcomes.
9. Remove dead-letter data according to retention policy.

## Example

```ruby
class ProcessPaymentEventJob < ApplicationJob
  retry_on Faraday::TimeoutError, wait: :polynomially_longer, attempts: 5

  # Permanent failures are parked with their original payload and id for a
  # human decision, not retried forever or silently dropped.
  rescue_from PaymentEvent::Malformed do |error|
    DeadLetter.create!(queue: queue_name, job_class: self.class.name, job_id: job_id,
                       arguments: serialize["arguments"], error: error.message)
  end

  def perform(event_payload)
    PaymentEvent.parse!(event_payload).apply!
  end
end

# Controlled replay keeps the original identity for idempotency.
DeadLetter.find(42).then { |letter| letter.job_class.constantize.perform_later(*ActiveJob::Arguments.deserialize(letter.arguments)) }
```

## Failure modes

- infinite poison-message retries
- destructive replay
- new identity generated during replay
- sensitive payload copied into logs/diagnostics
- replay bypasses current validation
- no owner for remediation

## Testing

Test retry exhaustion, dead-letter routing, replay of a fixed message, replay of an unresolved message, authorization, and idempotent side effects.

## Review checklist

- [ ] terminal conditions explicit
- [ ] identity preserved
- [ ] metadata safe
- [ ] replay authorization enforced
- [ ] replay rate bounded
- [ ] handler idempotency verified
- [ ] audit trail exists

## Related skills

- rails-event-driven-messaging
- rails-distributed-systems
- rails-security
- rails-observability

## Related patterns

- message-delivery-contract
- inbox-deduplication
