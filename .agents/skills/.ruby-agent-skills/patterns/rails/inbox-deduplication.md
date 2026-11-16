---
name: inbox-deduplication
description: Deduplicate at-least-once message delivery with durable message identity and a side-effect boundary.
family: rails
---

# Inbox Deduplication

## Problem

A consumer can receive the same logical message more than once because of retries, redelivery, or replay.

## Use when

A message/event can be delivered at least once and duplicate side effects are not acceptable.

## Do not use when

The downstream effect is demonstrably idempotent and no durable duplicate tracking is required.

## Repository inspection

Inspect message identity, consumer database, unique constraints, transaction scope, side effects, acknowledgement semantics, and existing idempotent job patterns.

## Implementation procedure

1. Define the message/event identity scope.
2. Bind identity to the correct producer/type/tenant namespace.
3. Reserve or insert inbox state under a database uniqueness constraint.
4. Apply the side effect and completion state in the correct transaction boundary.
5. Decide whether duplicate delivery returns prior success, no-ops, or replays safely.
6. Handle consumer crash before and after the side effect.
7. Retain enough history for the supported replay window.
8. Use idempotent-job for any subsequent Active Job execution.

## Example

```ruby
# Unique index on processed_messages.message_id makes the insert the dedup decision.
class PaymentCapturedConsumer
  def call(envelope)
    ActiveRecord::Base.transaction do
      ProcessedMessage.create!(message_id: envelope.fetch("id"), consumer: self.class.name)
      order = Order.lock.find(envelope.dig("payload", "order_id"))
      order.update!(status: :paid)
    end
    :ack
  rescue ActiveRecord::RecordNotUnique
    :ack # already processed in a committed transaction; acknowledge the duplicate
  end
end
# add_index :processed_messages, %i[consumer message_id], unique: true
```

## Failure modes

- process-local deduplication
- missing unique constraint
- marking processed before durable side effect
- message identity changes on retry
- inbox table grows without retention/recovery policy
- dedupe hides a poison message

## Testing

Test sequential duplicates, concurrent duplicates, crash/retry around the side effect, replay, same identity with conflicting payload, and retention behavior where applicable.

## Review checklist

- [ ] message identity is stable
- [ ] identity uniqueness is database-enforced
- [ ] side-effect boundary is explicit
- [ ] concurrent duplicate behavior is tested
- [ ] replay policy is explicit
- [ ] retention is bounded

## Related skills

- rails-distributed-systems
- rails-database-engineering
- rails-active-job
- rails-test-engineering

## Related patterns

- idempotent-job
- message-delivery-contract
- database-constraint
