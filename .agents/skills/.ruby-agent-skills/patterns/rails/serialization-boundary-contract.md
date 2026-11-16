---
name: serialization-boundary-contract
description: Serialization Boundary Contract
family: rails
---
# Serialization Boundary Contract

## Problem
Internal model shape becomes an accidental external contract when serialization ownership is implicit.

## Use when
Adding or changing a serialized representation consumed outside the owning object.

## Do not use when
Purely internal object inspection with no transport or persistence contract.

## Repository inspection
Inspect consumers, serializer or presenter code, response tests, fixtures, and model attributes.

## Implementation procedure
Define owner, schema, allowed fields, null semantics, compatibility policy, and transport boundary explicitly.

## Example

```ruby
# The API representation is owned by the boundary, not derived from the table.
module Api
  module V1
    class OrderRepresentation
      def initialize(order) = @order = order

      def as_json(*)
        {
          id: @order.public_id,             # not the database primary key
          status: @order.status,
          total: { amount: @order.total_cents, currency: @order.currency },
          placed_at: @order.placed_at&.utc&.iso8601
        }
      end
    end
  end
end

# render json: Api::V1::OrderRepresentation.new(order)
```

## Failure modes
Database schema leaks, accidental fields, ambiguous ownership, incompatible changes.

## Testing
Assert exact contract shape at the boundary.

## Review checklist
[ ] owner [ ] schema [ ] sensitive fields [ ] compatibility

## Related skills
rails-serialization-globalid-engineering, rails-api-integration