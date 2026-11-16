---
name: mailer-delivery-semantics
description: Choose and verify synchronous versus asynchronous Rails email delivery with transaction, retry, duplicate, and queue semantics.
family: rails
---

# Mailer Delivery Semantics

## Problem

Changing deliver_now to deliver_later changes latency, failure timing, queue behavior, and duplicate-delivery semantics.

## Use when

- selecting delivery mode;
- changing queue or retry behavior;
- diagnosing delayed/duplicated mail.

## Do not use when

- email is not part of the execution contract.

## Repository inspection

Inspect Active Job adapter, queue policy, retry/discard rules, transaction boundaries, mail delivery jobs, and existing idempotency conventions.

## Implementation procedure

1. Define whether delivery may be delayed.
2. Define the business event that requires the mail.
3. Verify committed-state timing.
4. Select deliver_now or deliver_later.
5. Define retryable/permanent/unknown outcomes.
6. Define duplicate handling.
7. Verify queue capacity and observability.

## Example

```ruby
class OrdersController < ApplicationController
  def create
    @order = Current.account.orders.create!(order_params)
    # deliver_later enqueues after this transaction; with enqueue_after_transaction_commit
    # (Rails 7.2+ default) the job cannot run before the order row is visible.
    OrderMailer.confirmation(@order).deliver_later
    redirect_to @order
  end
end

class PasswordsController < ApplicationController
  def create
    user = User.find_by(email_address: params[:email_address])
    # deliver_now only where the request must know the handoff to the provider happened.
    PasswordsMailer.reset(user).deliver_later if user
    redirect_to new_session_path, notice: "If that address exists, instructions are on the way."
  end
end
```

## Failure modes

- synchronous provider latency in request path;
- asynchronous delivery before commit;
- duplicate delivery after ambiguous provider failure;
- unbounded retry amplification;
- incorrect queue selection.

## Testing

Assert delivery mode, enqueued job arguments, transaction behavior, failure classification, and duplicate-safe business semantics.

## Review checklist

- [ ] latency contract
- [ ] transaction semantics
- [ ] queue semantics
- [ ] retry classification
- [ ] duplicate/unknown outcome handling
- [ ] tests

## Related skills

rails-action-mailer, rails-active-job, rails-reliability-engineering, rails-distributed-systems
