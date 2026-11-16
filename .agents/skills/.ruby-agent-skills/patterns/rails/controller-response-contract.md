---
name: controller-response-contract
description: Use when a controller action's status, body, headers, format, or redirect behavior is part of an HTTP contract.
family: rails
---

# Controller Response Contract

## Problem

Small controller refactors can accidentally change status codes, content types, redirects, headers, or render behavior even when domain behavior is unchanged.

## Use when

- adding explicit response handling
- supporting multiple formats
- changing redirect behavior
- changing error or empty responses
- reviewing an endpoint contract.

## Do not use when

- the task is purely internal and response behavior is proven unchanged.

## Repository inspection

Inspect routes, request tests, serializers/views, response helpers, API conventions, and neighboring controllers.

## Implementation procedure

1. State the successful response.
2. State expected client and domain failures.
3. Define format behavior.
4. Define redirect behavior and status.
5. Define important headers and cache validators.
6. Ensure only one response path executes.
7. Test the observable contract.

## Example

```ruby
class OrdersController < ApplicationController
  # The response contract per outcome is explicit: status, format, location.
  def create
    order = current_account.orders.build(order_params)
    if order.save
      render json: OrderSerializer.new(order), status: :created, location: order
    else
      render json: { errors: order.errors.details }, status: :unprocessable_content
    end
  end

  def destroy
    current_account.orders.find(params[:id]).destroy!
    head :no_content
  end
end
```

## Failure modes

- relying on implicit behavior after changing the response shape
- rendering and redirecting on the same path
- forgetting that redirect_to does not stop Ruby execution
- using a status merely because it is conventional.

## Testing

Use request tests asserting status, content type, body/representation, headers, and redirect location.

## Review checklist

- [ ] response contract is explicit
- [ ] format behavior is deterministic
- [ ] status codes are intentional
- [ ] headers are reviewed
- [ ] no double render/redirect path exists

## Related skills

rails-action-controller, rails-api-integration, rails-observability, rails-test-engineering
