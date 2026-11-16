---
name: regression-test
description: Use when fixing a defect so the previously failing behavior becomes an explicit executable contract.
family: testing
---

# Regression Test

## Problem

A defect can return because the original failure was never encoded as a test.

## Use when

- fixing a bug
- changing behavior after a production incident
- refactoring code with a previously fragile edge case

## Do not use when

- the behavior is intentionally changing and the old behavior is no longer a contract

## Repository inspection

Find the narrowest existing test boundary that reproduces the failure and follow its framework/convention.

## Implementation procedure

1. Reproduce the failure.
2. Capture the smallest meaningful input/state.
3. Write a test that fails for the original reason.
4. Apply the fix.
5. Verify the regression test passes.
6. Run affected regression checks.

## Example

```ruby
# Regression for #1482: a discount code applied twice reduced the total twice.
class DiscountRegressionTest < ActiveSupport::TestCase
  test "applying the same code twice discounts once" do
    order = orders(:cart_with_100_dollars)

    order.apply_discount!("SAVE10")
    order.apply_discount!("SAVE10")

    assert_equal 90_00, order.reload.total_cents
  end
end
```

## Failure modes

- test only asserts the new implementation detail
- test passes before the fix
- overly broad fixture hides the actual trigger
- changing the test instead of fixing the defect

## Testing

A regression test should communicate:

~~~text
given the triggering condition
when the operation occurs
then the previously broken contract now holds
~~~

## Review checklist

- [ ] test reproduces the original failure
- [ ] test is deterministic
- [ ] assertion describes behavior
- [ ] fix is independently reviewable

## Related skills

- ruby-debugging
- ruby-tdd-refactoring
- rails-test-engineering
