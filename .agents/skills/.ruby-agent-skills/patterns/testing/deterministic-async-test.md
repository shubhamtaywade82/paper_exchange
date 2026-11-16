---
name: deterministic-async-test
description: Test asynchronous Rails jobs without sleeps, timing races, or bypassing the relevant framework boundary.
family: testing
---

# Deterministic Async Test

## Problem
Asynchronous code is commonly tested with sleeps or direct method calls that bypass serialization and queue behavior.

## Use when
Testing Active Job, delayed side effects, polling, or asynchronous workflow boundaries.

## Implementation procedure
1. Identify enqueue versus execution contract.
2. Assert enqueue with ActiveJob::TestHelper when applicable.
3. Use perform_enqueued_jobs for controlled execution.
4. Control time explicitly.
5. Replace sleeps with condition-driven/test-helper synchronization.
6. Test retry/failure behavior at the intended boundary.

## Example

```ruby
class OrderConfirmationTest < ActiveJob::TestCase
  test "placing an order enqueues exactly one confirmation" do
    order = orders(:pending)

    assert_enqueued_with(job: OrderConfirmationJob, args: [order]) do
      order.place!
    end
  end

  test "the job delivers the confirmation when performed" do
    order = orders(:pending)

    perform_enqueued_jobs do
      OrderConfirmationJob.perform_later(order)
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal [order.customer.email], ActionMailer::Base.deliveries.last.to
  end
end
```

## Failure modes
- Thread.sleep/sleep-based assertions
- direct perform as the only job test
- real queue worker in ordinary unit tests
- test passes because the race was hidden

## Testing
Cover both enqueue and execution when both are part of the contract.

## Review checklist
- queue boundary tested
- serialization not accidentally bypassed
- no sleep-based synchronization
- deterministic execution


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture

## Do not use when

Do not use when the behavior is synchronous and has no asynchronous scheduling or execution boundary.
