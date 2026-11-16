---
name: i18n-localized-routing
description: Design locale-aware Rails routes and URL generation with bounded locale parameters and stable navigation semantics.
family: rails
---

# I18n Localized Routing

## Problem

Adding locale to URLs without routing constraints can create inconsistent URLs, unsupported locales, and cache dimensions that do not match application behavior.

## Use when

- adding locale routes;
- changing URL locale propagation;
- using localized domains/subdomains.

## Do not use when

- locale never appears in the URL/domain contract.

## Repository inspection

Inspect routes, default_url_options, locale resolver, URL helpers, canonical URLs, and existing route tests.

## Implementation procedure

1. Choose path/domain/query representation.
2. Constrain supported locale values.
3. Set request locale from the route boundary.
4. Propagate locale through generated URLs.
5. Define default/omitted behavior.
6. Test canonical and invalid locale URLs.

## Example

```ruby
# config/routes.rb — only supported locales match; everything else 404s.
Rails.application.routes.draw do
  scope "(:locale)", locale: /en|hi|mr/ do
    resources :products, only: %i[index show]
    root "home#show"
  end
end

class ApplicationController < ActionController::Base
  around_action { |_, action| I18n.with_locale(params[:locale] || I18n.default_locale, &action) }

  # Generated URLs carry the current locale.
  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end
end
```

## Failure modes

- arbitrary locale routes;
- locale omitted from generated links;
- duplicate canonical URLs;
- locale in route but not in cache identity.

## Testing

Test localized routes, invalid locale rejection/fallback, and generated URL propagation.

## Review checklist

- [ ] representation
- [ ] constraint
- [ ] request integration
- [ ] URL propagation
- [ ] default behavior
- [ ] tests

## Related skills

rails-i18n, rails-routing, rails-caching
