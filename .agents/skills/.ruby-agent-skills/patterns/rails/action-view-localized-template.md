---
name: action-view-localized-template
description: Define locale-specific Action View template selection without duplicating authorization or business behavior.
family: rails
---

# Action View Localized Template

## Problem

Localized templates can diverge in behavior if they are treated as separate implementations instead of presentation variants.

## Use when

- adding locale-specific view variants;
- changing localized fallback behavior;
- debugging locale-specific rendering differences.

## Do not use when

- localization is limited to translation keys and no localized templates are needed.

## Repository inspection

Inspect rails-i18n conventions, supported locales, template naming, fallback behavior, and tests.

## Implementation procedure

1. Define the supported locale set.
2. Add only variants that materially differ in presentation.
3. Keep domain logic shared outside templates.
4. Define fallback to the canonical template.
5. Test supported and fallback locales.
6. Include locale in cache identity when output varies by locale.

## Example

```erb
<%# app/views/orders/_summary.html.erb — one template; wording comes from
    translations, so every locale renders the same structure and rules. %>
<section>
  <h2><%= t(".heading") %></h2>
  <p><%= t(".items", count: order.line_items.size) %></p>
  <p><%= t(".total", amount: number_to_currency(order.total_cents / 100.0)) %></p>
  <p><%= l(order.placed_at, format: :long) %></p>
</section>
```

## Failure modes

- business rules duplicated per locale;
- unsupported locale selects a privileged variant;
- locale-specific cache collisions;
- fallback behavior assumed rather than tested.

## Testing

Test localized template selection, fallback, and cache isolation where applicable.

## Review checklist

- [ ] supported locale set explicit
- [ ] fallback explicit
- [ ] business logic not duplicated
- [ ] locale cache dimension reviewed
- [ ] tests cover variants

## Related skills

- skills/rails-action-view/SKILL.md
- skills/rails-i18n/SKILL.md
- skills/rails-caching/SKILL.md
