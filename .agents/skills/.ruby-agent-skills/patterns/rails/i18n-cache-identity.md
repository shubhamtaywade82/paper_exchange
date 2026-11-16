---
name: i18n-cache-identity
description: Decide when locale belongs in Rails cache identity and prevent localized content from crossing locale boundaries.
family: rails
---

# I18n Cache Identity

## Problem

Localized representations can leak across users/locales when cache keys ignore presentation locale.

## Use when

- caching translated views/API responses;
- changing locale-aware fragment or low-level cache keys.

## Do not use when

- the cached value is intentionally locale-independent.

## Repository inspection

Inspect cache layer, representation, locale selection, key construction, CDN behavior, and cache invalidation.

## Implementation procedure

1. Determine whether value depends on locale.
2. Identify locale identity dimension.
3. Add locale only when required.
4. Version key if representation contract changes.
5. Test cross-locale isolation.

## Example

```erb
<%# Cache key varies by locale because the rendered text does; by product version because the content does. %>
<% cache [I18n.locale, @product] do %>
  <h2><%= @product.name %></h2>
  <p><%= t(".price", price: number_to_currency(@product.price)) %></p>
  <p><%= l(@product.released_on, format: :long) %></p>
<% end %>
<%# Not included: current user. This fragment is identical for every viewer. %>
```

## Failure modes

- localized output shared across locales;
- unnecessary locale cardinality;
- CDN/cache variation mismatch.

## Testing

Assert same resource with different locales does not collide when output differs.

## Review checklist

- [ ] locale dependency
- [ ] key decision
- [ ] versioning
- [ ] CDN/HTTP variation
- [ ] tests

## Related skills

rails-i18n, rails-caching, rails-performance
