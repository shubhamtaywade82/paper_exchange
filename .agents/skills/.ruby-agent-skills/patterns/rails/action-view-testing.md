---
name: action-view-testing
description: Verify Action View rendering contracts deterministically at the smallest boundary that proves behavior.
family: rails
---

# Action View Testing

## Problem

View changes can be tested too broadly with brittle full-page snapshots or too narrowly without proving escaping and local contracts.

## Use when

- changing templates, partials, layouts, helpers, or localized views;
- fixing rendering or security bugs;
- adding strict local contracts.

## Do not use when

- the behavior belongs entirely to controller routing or domain logic.

## Repository inspection

Inspect the repository's view/request/system test style, helper tests, HTML assertion library, and existing snapshot usage.

## Implementation procedure

1. Choose the smallest test boundary.
2. Assert the stable user-visible contract.
3. Test malicious or untrusted output when relevant.
4. Test required and default locals for strict partials.
5. Test layout or locale selection when behavior changes.
6. Use request/system tests for cross-layer rendering behavior.
7. Avoid brittle assertions on incidental HTML formatting.

## Example

```ruby
class OrdersViewTest < ActionView::TestCase
  test "partial escapes user content and honours its locals" do
    order = orders(:one)
    order.number = %(<script>alert(1)</script>)

    render partial: "orders/order", locals: { order: order, compact: true }

    assert_includes rendered, "&lt;script&gt;"
    assert_not_includes rendered, "<script>"
    assert_no_match(/order-status/, rendered) # compact omits the status
  end

  test "missing required local raises" do
    assert_raises(ActionView::Template::Error) { render partial: "orders/order", locals: {} }
  end
end
```

## Failure modes

- giant snapshots;
- implementation-detail assertions;
- no XSS regression test;
- no missing-local coverage;
- tests coupled to external services.

## Testing

Cover the changed rendering contract, negative security cases, and cross-layer behavior when applicable.

## Review checklist

- [ ] test boundary justified
- [ ] stable contract asserted
- [ ] security case included
- [ ] locale/layout/local behavior covered
- [ ] external dependencies isolated

## Related skills

- skills/rails-action-view/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/rails-security/SKILL.md
