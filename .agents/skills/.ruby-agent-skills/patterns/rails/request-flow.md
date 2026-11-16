---
name: request-flow
description: Use when implementing an HTTP feature that crosses routing, controller, authorization, domain logic, persistence, and response layers.
family: rails
---

# Rails Request Flow

## Problem

A feature crosses several Rails boundaries and can easily leak responsibilities between them.

## Use when

- adding an endpoint
- changing an existing request flow
- debugging an HTTP feature
- implementing a CRUD resource

## Do not use when

- the change is isolated to one internal object and has no request contract

## Repository inspection

Trace:

~~~text
route
  -> authentication
  -> authorization
  -> params
  -> application/domain operation
  -> persistence
  -> serializer/view
  -> HTTP response
~~~

Inspect the actual repository at each boundary before changing code.

## Implementation procedure

1. Define the HTTP contract.
2. Confirm route and verb.
3. Confirm authentication/authorization.
4. Define accepted input.
5. Identify the owner of business behavior.
6. Persist through existing boundaries.
7. Define success/error response behavior.
8. Add request-level regression coverage.
9. Run focused and broader checks.

## Example

```ruby
# Route -> controller (HTTP) -> model (domain) -> view/JSON (presentation).
# config/routes.rb:  resources :orders, only: :create

class OrdersController < ApplicationController
  def create
    @order = Current.account.orders.build(order_params) # tenant scope, strong params
    authorize @order
    if @order.place # domain behavior lives on the model
      redirect_to @order, notice: t(".placed")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def order_params = params.expect(order: [:sku, :quantity])
end

class Order < ApplicationRecord
  def place
    self.status = "placed"
    save
  end
end
```

## Failure modes

- business logic in controller
- authorization only in views
- response shape changed accidentally
- persistence rules duplicated in request handling
- endpoint works only for the happy path

## Testing

At minimum, cover the meaningful success path plus invalid/unauthorized/error paths relevant to the endpoint.

## Review checklist

- [ ] route is correct
- [ ] authn/authz enforced
- [ ] params are controlled
- [ ] business logic has a clear owner
- [ ] response contract preserved
- [ ] request regression test exists

## Related skills

- rails-routing
- rails-action-controller
- rails-authentication
- rails-active-record
- rails-test-engineering
- rails-architecture

## Book integration: request-test boundary

When the behavior crosses the Rails request boundary, verify it at request level rather than relying only on controller implementation tests. The test should exercise routing, authentication/authorization, permitted parameters, domain/service behavior, persistence, and observable response behavior as appropriate.
