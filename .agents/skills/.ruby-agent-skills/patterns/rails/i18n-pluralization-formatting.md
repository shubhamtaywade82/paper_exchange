---
name: i18n-pluralization-formatting
description: Use Rails I18n pluralization and locale-aware date/time/number formatting instead of hand-built language rules or presentation strings.
family: rails
---

# I18n Pluralization & Formatting

## Problem

Manual singular/plural logic and hard-coded number/date formatting break across languages and regional conventions.

## Use when

- localizing counts;
- changing date/time/number/currency presentation.

## Do not use when

- values are canonical storage data rather than localized presentation.

## Repository inspection

Inspect locale formats, supported locale differences, count contracts, timezone handling, and presentation helpers.

## Implementation procedure

1. Identify canonical value.
2. Identify locale context.
3. Use pluralization rules with count.
4. Use locale-aware format helpers.
5. Keep timezone separate from locale.
6. Test representative grammar/format differences.

## Example

```ruby
# config/locales/en.yml
#   en:
#     cart:
#       items:
#         zero: "Your cart is empty"
#         one: "%{count} item"
#         other: "%{count} items"

I18n.t("cart.items", count: 0) # => "Your cart is empty"
I18n.t("cart.items", count: 1) # => "1 item"
I18n.t("cart.items", count: 3) # => "3 items"

# Locale rules own separators, symbols, and date order.
ActiveSupport::NumberHelper.number_to_currency(1_234_567.5, locale: :en) # => "$1,234,567.50"
I18n.l(Date.new(2026, 3, 9), format: :long, locale: :en)                  # => "March 09, 2026"

# Wrong: "#{count} item#{'s' unless count == 1}" hard-codes English grammar.
```

## Failure modes

- count == 1 in application code;
- localized strings persisted as domain data;
- timezone inferred from locale;
- one format assumed for every locale.

## Testing

Cover pluralization and at least one materially different formatting locale.

## Review checklist

- [ ] canonical data
- [ ] locale context
- [ ] pluralization
- [ ] formatting
- [ ] timezone separation
- [ ] tests

## Related skills

rails-i18n, rails-action-view, rails-active-record
