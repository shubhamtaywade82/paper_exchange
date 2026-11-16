---
name: system-test-contract
description: Use Rails system tests only for user-visible browser behavior that lower-level tests cannot prove reliably.
family: testing
---

# System Test Contract

## Problem
Browser/system tests provide realistic coverage but add substantial setup and runtime cost.

## Use when
Testing JavaScript, browser navigation, UI interaction, or full user journeys.

## Do not use when
A model, service, request, or integration test can prove the contract without a browser.

## Implementation procedure
1. Identify the user-visible behavior.
2. Define the minimal journey.
3. Keep data setup explicit.
4. Assert user-observable outcomes.
5. Capture screenshots on failure when useful.
6. Keep business-rule assertions in lower-level tests.

## Example

```ruby
# One journey that needs a real browser; calculation details stay in
# model tests.
class CheckoutJourneyTest < ApplicationSystemTestCase
  test "choosing express shipping updates the total and completes checkout" do
    sign_in users(:sam)
    visit checkout_path

    choose "Express shipping"
    assert_text "Total $45.00"

    click_on "Place order"
    assert_text "Order confirmed"
  end
end
```

## Failure modes
- browser test for pure domain logic
- giant end-to-end scenario covering unrelated features
- brittle CSS/DOM internals
- duplicate assertions from lower-level tests

## Testing
Run the system test and the lower-level contract tests it complements.

## Review checklist
- browser dependency is justified
- journey is minimal
- assertions are user-visible
- business rules are tested lower in the stack


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
