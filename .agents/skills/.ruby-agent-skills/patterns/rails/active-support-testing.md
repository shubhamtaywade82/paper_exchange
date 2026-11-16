---
name: active-support-testing
description: Test Active Support composition, context, configuration, callbacks, instrumentation, and time semantics deterministically.
family: rails
---

# Active Support Testing

## Problem

Active Support often relies on global registries, inherited configuration, callbacks, notification subscribers, and request-local state, making test leakage easy.

## Use when

- adding or changing Active Support primitives;
- testing concerns, CurrentAttributes, notifications, class configuration, or time behavior.

## Do not use when

- the behavior has no Active Support-specific lifecycle/state contract.

## Repository inspection

Inspect test helpers, global cleanup/reset conventions, notification subscribers, CurrentAttributes reset hooks, timezone helpers, and parallel-test settings.

## Implementation procedure

1. Select the smallest boundary that proves the contract.
2. Isolate global/inherited state per test.
3. Reset CurrentAttributes and timezone context.
4. Subscribe to Notifications temporarily only when the test requires it.
5. Verify parent/subclass configuration isolation.
6. Test callbacks explicitly.
7. Test time semantics with deterministic clocks/helpers.

## Example

```ruby
class CheckoutInstrumentationTest < ActiveSupport::TestCase
  # Global state touched by the test is restored after it.
  teardown do
    Current.reset
    ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
  end

  test "checkout emits one event with the documented payload" do
    events = []
    @subscriber = ActiveSupport::Notifications.subscribe("checkout.shop") { |event| events << event }

    Checkout.new.call(orders(:one))

    assert_equal 1, events.size
    assert_equal %i[line_item_count order_id], events.first.payload.keys.sort
  end

  test "reports use the account time zone" do
    Time.use_zone("Asia/Kolkata") do
      travel_to Time.zone.local(2026, 1, 1, 0, 30) do
        assert_equal Date.new(2026, 1, 1), DailyReport.new.report_date
      end
    end
  end
end
```

## Failure modes

- notification subscribers leak across tests;
- CurrentAttributes state leaks;
- class_attribute changes persist between examples;
- timezone remains changed;
- tests depend on execution order.

## Testing

Cover isolation, reset, inheritance, event payloads, callback order, timezone boundaries, and dynamic-name rejection where applicable.

## Review checklist

- [ ] global/context state isolated
- [ ] subscribers cleaned up
- [ ] timezone restored
- [ ] inherited config restored
- [ ] deterministic test data/time

## Related skills

- skills/rails-active-support/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/ruby-concurrency/SKILL.md
