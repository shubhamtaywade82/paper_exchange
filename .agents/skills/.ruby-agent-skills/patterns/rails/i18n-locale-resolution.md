---
name: i18n-locale-resolution
description: Resolve Rails locale from trusted application inputs with explicit precedence, supported-locale validation, and deterministic fallback.
family: rails
---

# I18n Locale Resolution

## Problem

Locale selection becomes inconsistent or unsafe when controllers, middleware, views, and user preferences each choose a locale independently.

## Use when

- adding locale negotiation;
- changing locale precedence;
- adding URL/domain/user/header locale sources.

## Do not use when

- the application has no locale-selection boundary.

## Repository inspection

Inspect available locales, default locale, current locale resolver, URL conventions, user/account preference, accepted-language handling, and tests.

## Implementation procedure

1. Enumerate supported locales.
2. Define precedence.
3. Normalize incoming values.
4. Reject unsupported values.
5. Apply deterministic fallback.
6. Establish the scoped locale context.
7. Test conflicting locale sources.

## Example

```ruby
class ApplicationController < ActionController::Base
  around_action :switch_locale

  private

  # One precedence order: explicit param > user preference > Accept-Language > default.
  def switch_locale(&action)
    I18n.with_locale(resolved_locale, &action)
  end

  def resolved_locale
    [params[:locale], Current.user&.locale, accept_language].each do |candidate|
      locale = candidate.to_s.strip.downcase
      return locale.to_sym if I18n.available_locales.map(&:to_s).include?(locale)
    end
    I18n.default_locale
  end

  def accept_language
    request.headers["Accept-Language"].to_s.split(",").first.to_s.split(/[-;]/).first
  end
end
```

## Failure modes

- arbitrary locale accepted;
- inconsistent precedence;
- unsupported locale leaks into runtime;
- locale selection used as authorization.

## Testing

Test every source and precedence conflict plus unsupported/fallback behavior.

## Review checklist

- [ ] supported locales
- [ ] precedence
- [ ] normalization
- [ ] fallback
- [ ] scoped context
- [ ] tests

## Related skills

rails-i18n, rails-routing, rails-authentication, rails-security
