---
name: validation-error-contract
description: Use when Rails validation errors cross form, API, service, or other presentation boundaries.
family: rails
---

# Validation Error Contract

## Problem
Validation Error Contract needs an explicit contract so validation does not drift between model logic, database integrity, and consumers.

## Use when
- errors cross UI, API, service, job, or logging boundaries.

## Do not use when
- human-readable prose is treated as an undocumented machine protocol;
- sensitive internal details are exposed.

## Repository inspection
- errors usage;
- API serializers;
- forms;
- locale files;
- tests/client consumers.

## Implementation procedure
1. Identify consumer contract.
2. Preserve stable attribute/type/detail identity.
3. Localize at presentation boundaries.
4. Avoid coupling clients to prose.
5. Add regression tests for the shape.

## Example

```ruby
class Api::V1::OrdersController < ActionController::API
  def create
    order = Current.account.orders.build(params.expect(order: %i[sku quantity]))
    if order.save
      render json: { id: order.id }, status: :created
    else
      # Stable machine-readable shape: attribute + error type, with a human message.
      render json: {
        errors: order.errors.map { |e| { attribute: e.attribute, type: e.type, message: e.full_message } }
      }, status: :unprocessable_entity
    end
  end
end
# {"errors":[{"attribute":"quantity","type":"greater_than","message":"Quantity must be greater than 0"}]}
```

## Failure modes
- wording changes break clients;
- base errors are serialized incorrectly;
- sensitive information leaks.

## Testing
- attribute/type/details;
- full-message rendering when needed;
- API JSON;
- localization.

## Review checklist
- [ ] machine identity is stable
- [ ] presentation is separate
- [ ] no sensitive data leaks

## Related skills
- rails-validations
- rails-active-record
- rails-database-engineering
- rails-test-engineering
