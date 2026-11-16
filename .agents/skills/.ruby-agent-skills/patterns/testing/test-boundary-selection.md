---
name: test-boundary-selection
description: Select the smallest Rails test boundary that proves the required contract.
family: testing
---

# Test Boundary Selection

## Problem
A behavior can be tested at model, service, request, integration, system, job, or other boundaries.

## Use when
Adding or reviewing tests for Rails behavior.

## Implementation procedure
1. State the observable contract.
2. Identify the layer that owns it.
3. Prefer the smallest test that proves it.
4. Add a higher-level test only when it proves a distinct cross-layer contract.
5. Avoid duplicating identical assertions across layers.

## Example

```ruby
# Pricing rules: model test (fast, many cases).
class PriceTest < ActiveSupport::TestCase
  test "applies the bulk discount at 10 units" do
    assert_equal 900_00, Price.new(unit_cents: 100_00, quantity: 10).total_cents
  end
end

# HTTP contract: one request test proves routing, auth, params, and response.
class OrdersRequestTest < ActionDispatch::IntegrationTest
  test "creates an order" do
    sign_in users(:sam)
    post orders_path, params: { order: { sku: "SKU-1", quantity: 10 } }
    assert_redirected_to order_path(Order.last)
  end
end
```

## Failure modes
- system test for a pure domain rule
- controller test for an HTTP contract when request tests are used
- unit test as the only proof of a job enqueue integration
- broad integration test for every local behavior

## Testing
Verify both the focused contract and any distinct integration path.

## Review checklist
- owning boundary identified
- contract observable
- no unnecessary duplicate layers
- failure behavior covered


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture

## Do not use when

Do not use when the test boundary is already explicitly prescribed by the task or repository contract.
