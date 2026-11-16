---
name: action-view-helper-boundary
description: Keep Rails view helpers focused on presentation transformations instead of hiding domain workflows.
family: rails
---

# Action View Helper Boundary

## Problem

Helpers are convenient enough that they can accumulate queries, policy, network calls, and domain orchestration.

## Use when

- adding a helper;
- refactoring a large helper;
- diagnosing hidden query or side-effect behavior in views.

## Do not use when

- the helper is a small deterministic formatter or tag builder.

## Repository inspection

Inspect helper modules, presenters, decorators, domain services, query objects, and tests.

## Implementation procedure

1. Name the presentation responsibility.
2. Keep collaborators explicit.
3. Avoid writes and external calls.
4. Minimize hidden queries.
5. Extract domain logic to its owning boundary.
6. Keep the helper as a thin rendering adapter.
7. Add focused tests.

## Example

```ruby
module OrdersHelper
  # Formatting only: data and permission decisions arrive as arguments.
  def order_status_badge(order)
    tag.span(order.status.humanize, class: ["badge", "badge--#{order.status.dasherize}"])
  end

  def money(cents, currency: "USD")
    number_to_currency(cents / 100.0, unit: currency == "USD" ? "$" : currency)
  end
end

# Not a helper responsibility:
#   def can_refund?(order) = RefundPolicy.new(current_user, order).allowed?   # policy
#   def recent_orders = Order.where(...).limit(5)                              # query
```

## Failure modes

- helper as service object;
- helper queries collection data;
- helper performs authorization inconsistently;
- helper calls external APIs;
- helper mutates state.

## Testing

Test output independently and verify expensive or domain behavior is executed at the owning boundary.

## Review checklist

- [ ] presentation responsibility clear
- [ ] no writes
- [ ] no hidden external calls
- [ ] query behavior understood
- [ ] tests focused

## Related skills

- skills/rails-action-view/SKILL.md
- skills/rails-action-view/SKILL.md
- skills/ruby-service-objects/SKILL.md
- skills/ruby-domain-modeling/SKILL.md
