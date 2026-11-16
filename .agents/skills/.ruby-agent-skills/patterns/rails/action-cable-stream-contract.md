---
name: action-cable-stream-contract
description: Define deterministic, bounded, authorization-safe Action Cable stream names and broadcasting identities.
family: rails
---

# Action Cable Stream Contract

## Problem

Stream names form the pub/sub namespace; weak naming can cause collisions or authorization bypasses.

## Use when

- adding stream_from/stream_for;
- changing broadcast_to or channel identifiers.

## Do not use when

- the framework's canonical resource stream is already used without additional scope.

## Repository inspection

Inspect resource identity, tenant boundaries, stream helpers, broadcast producers, and existing naming conventions.

## Implementation procedure

1. Define the logical audience.
2. Include required tenant/resource identity.
3. Prefer stream_for/broadcast_to for resource identity.
4. Bound explicit names.
5. Keep client input out of the namespace where possible.
6. Test same-resource and cross-scope separation.

## Example

```ruby
class OrderChannel < ApplicationCable::Channel
  def subscribed
    order = current_user.orders.find_by(id: params[:order_id]) or return reject

    # stream_for derives a namespaced, globally unique name from the record
    # ("order:Z2lkOi8v..."), instead of a hand-built "orders_#{id}" string
    # that could collide across tenants or models.
    stream_for order
  end
end

OrderChannel.broadcast_to(order, { v: 1, type: "order.shipped", id: order.id })
```

## Failure modes

- global stream for private data;
- tenant collision;
- arbitrary client stream name;
- raw user input in stream key.

## Testing

Assert deterministic stream identity and isolation across tenants/resources.

## Review checklist

- [ ] namespace
- [ ] tenant scope
- [ ] canonical identity
- [ ] bounded name
- [ ] isolation tests

## Related skills

rails-action-cable, rails-security, rails-caching
