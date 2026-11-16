---
name: i18n-security-boundary
description: Review Rails localization inputs, translated HTML, interpolation values, locale administration, and localized caches for security and privacy risks.
family: rails
---

# I18n Security Boundary

## Problem

Localization can become an XSS, data-exfiltration, authorization, or cache-isolation boundary when locale input or translation content is trusted incorrectly.

## Use when

- accepting user-selected locale;
- allowing translation administration;
- rendering translated HTML;
- localizing private/tenant data.

## Do not use when

- translations are entirely static and already protected by repository conventions.

## Repository inspection

Inspect locale input sources, HTML-safe translation paths, authorization, interpolation data, translation admin, cache keys, and logs.

## Implementation procedure

1. Validate locale input.
2. Separate locale from authorization.
3. Review translated HTML/escaping.
4. Review interpolation sensitivity.
5. Secure translation editing.
6. Review cache isolation.
7. Add negative security tests.

## Example

```ruby
# Locale input is validated before it is used for anything (lookup, path, cache key).
SUPPORTED = I18n.available_locales.map(&:to_s).freeze

def safe_locale(raw)
  SUPPORTED.include?(raw.to_s) ? raw.to_sym : I18n.default_locale
end

# Interpolated user data is escaped: only keys ending in _html are html_safe,
# and Rails escapes interpolation values even inside them.
#   en:
#     welcome_html: "Welcome, <strong>%{name}</strong>"
helper.t("welcome_html", name: "<script>alert(1)</script>")
# => "Welcome, <strong>&lt;script&gt;alert(1)&lt;/script&gt;</strong>"

# Never: render template: "legal/terms.#{params[:locale]}"  (path traversal)
```

## Failure modes

- arbitrary locale selection used as access control;
- user HTML trusted as translation;
- secrets in interpolated translations/logs;
- cross-tenant localized cache.

## Testing

Test unsupported locale input, unsafe translation HTML, sensitive interpolation, translation-admin authorization, and locale cache separation.

## Review checklist

- [ ] locale validated
- [ ] authorization separate
- [ ] HTML escaped
- [ ] interpolation safe
- [ ] admin secured
- [ ] cache isolated

## Related skills

rails-i18n, rails-security, rails-security-engineering, rails-caching
